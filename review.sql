-- review.sql — Page de review d'une facture avec PDF, navigation prev/next, formulaire combiné

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- Redirect si pas d'id valide
SELECT 'redirect' AS component, 'invoices.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

-- ── Navigation prev/next parmi les factures pending_review ─────────────────

SET _prev = (
    SELECT id FROM (
        SELECT id,
               LEAD(id) OVER (ORDER BY overall_confidence ASC NULLS FIRST, processed_at DESC) AS next_id
          FROM accounting.invoice
         WHERE status = 'pending_review'
    ) sub
    WHERE next_id = $id::INT
);

SET _next = (
    SELECT id FROM (
        SELECT id,
               LAG(id) OVER (ORDER BY overall_confidence ASC NULLS FIRST, processed_at DESC) AS prev_id
          FROM accounting.invoice
         WHERE status = 'pending_review'
    ) sub
    WHERE prev_id = $id::INT
);

SET _pos = (
    SELECT pos FROM (
        SELECT id,
               ROW_NUMBER() OVER (ORDER BY overall_confidence ASC NULLS FIRST, processed_at DESC) AS pos
          FROM accounting.invoice
         WHERE status = 'pending_review'
    ) sub
    WHERE id = $id::INT
);

SET _total = (
    SELECT COUNT(*) FROM accounting.invoice WHERE status = 'pending_review'
);

-- ── Breadcrumb ─────────────────────────────────────────────────────────────

SELECT 'breadcrumb' AS component;

SELECT 'Dashboard' AS title, '/' AS link;
SELECT 'Invoices' AS title, '/invoices.sql?status=pending_review' AS link;
SELECT 'Review' AS title, TRUE AS active;

-- ── Save feedback ─────────────────────────────────────────────────────────

SELECT 'alert' AS component,
       'circle-check' AS icon,
       'green' AS color,
       'Changes saved successfully.' AS title,
       TRUE AS dismissible
 WHERE $saved = '1';

-- ── En-tête : position + navigation + actions rapides ──────────────────────

SELECT 'button' AS component, 'center' AS justify, 'sm' AS size;

SELECT 'Previous' AS title,
       'arrow-left' AS icon,
       'review.sql?id=' || $_prev AS link,
       CASE WHEN $_prev IS NULL THEN TRUE END AS disabled
 WHERE $_total::INT > 0;

SELECT $_pos || ' / ' || $_total AS title,
       'list-numbers' AS icon,
       TRUE AS disabled
 WHERE $_total::INT > 0;

SELECT 'Next' AS title,
       'arrow-right' AS icon_after,
       'review.sql?id=' || $_next AS link,
       CASE WHEN $_next IS NULL THEN TRUE END AS disabled
 WHERE $_total::INT > 0;

-- Store nav links for keyboard shortcuts
SET _validate_link = (
    SELECT 'update_status.sql?id=' || $id || '&status=validated&return=review&next=' || COALESCE($_next, '')
      FROM accounting.invoice WHERE id = $id::INT
);
SET _reject_link = (
    SELECT 'update_status.sql?id=' || $id || '&status=rejected&return=review&next=' || COALESCE($_next, '')
      FROM accounting.invoice WHERE id = $id::INT
);

SELECT 'button' AS component, 'end' AS justify, 'sm' AS size;

SELECT 'Validate' AS title,
       'green' AS color,
       'circle-check' AS icon,
       $_validate_link AS link,
       'review-validate-btn' AS id
  FROM accounting.invoice WHERE id = $id::INT;

SELECT 'Reject' AS title,
       'red' AS outline,
       'circle-x' AS icon,
       $_reject_link AS link,
       'review-reject-btn' AS id
  FROM accounting.invoice WHERE id = $id::INT;

SELECT 'Detail' AS title,
       'file-text' AS icon,
       'azure' AS outline,
       'invoice.sql?id=' || $id AS link
  FROM accounting.invoice WHERE id = $id::INT;

-- ── PDF embed (protected: only read file if pdf_available) ───────────────

SET _pdf_data_url = (
    SELECT sqlpage.read_file_as_data_url('uploads/' || COALESCE(renamed_filename, original_filename))
      FROM accounting.invoice
     WHERE id = $id::INT AND pdf_available = TRUE
);

SELECT 'html' AS component
 WHERE $_pdf_data_url IS NOT NULL;
SELECT '<iframe src="' || $_pdf_data_url || '" style="width:100%;height:80vh;border:1px solid #dee2e6;border-radius:.375rem" allowfullscreen></iframe>' AS html
 WHERE $_pdf_data_url IS NOT NULL;

-- Fallback si pas de PDF
SELECT 'alert' AS component,
       'No PDF available' AS title,
       'file-off' AS icon,
       'orange' AS color,
       'The PDF file is not available on the server. Upload it or re-run invoice_insert.py with --uploads-dir.' AS description
 WHERE $_pdf_data_url IS NULL;

-- ── Duplicate detection warning ───────────────────────────────────────────

SELECT 'alert' AS component,
       'Potential duplicate' AS title,
       'copy' AS icon,
       'orange' AS color,
       'Another invoice from the same supplier with a similar amount ('
           || dup.invoice_number || ' — ' || dup.total_amount || ' ' || COALESCE(dup.currency, '€')
           || ', dated ' || dup.issue_date::TEXT
           || ') exists.' AS description,
       'invoice.sql?id=' || dup.id AS link,
       'View duplicate' AS link_text,
       TRUE AS dismissible
  FROM accounting.invoice cur
  JOIN accounting.invoice dup
    ON dup.supplier_name = cur.supplier_name
   AND dup.id != cur.id
   AND ABS(COALESCE(dup.total_amount, 0) - COALESCE(cur.total_amount, 0)) < GREATEST(COALESCE(cur.total_amount, 0) * 0.05, 1)
   AND ABS(COALESCE(dup.issue_date, '1970-01-01'::DATE) - COALESCE(cur.issue_date, '1970-01-01'::DATE)) <= 30
 WHERE cur.id = $id::INT
 LIMIT 1;

-- ── KPIs ───────────────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 4 AS columns;

SELECT 'Total' AS title,
       COALESCE(i.total_amount::TEXT || ' ' || COALESCE(i.currency, ''), 'N/A') AS value,
       'currency-euro' AS icon,
       'green' AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Confidence' AS title,
       COALESCE(ROUND(i.overall_confidence * 100)::TEXT || '%', 'N/A') AS value,
       'target' AS icon,
       CASE WHEN i.overall_confidence >= 0.8 THEN 'green'
            WHEN i.overall_confidence >= 0.5 THEN 'orange'
            ELSE 'red' END AS color,
       ROUND(COALESCE(i.overall_confidence, 0) * 100)::INT AS progress_percent
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Line Items' AS title,
       (SELECT COUNT(*) FROM accounting.invoice_item
         WHERE invoice_number = i.invoice_number)::TEXT AS value,
       'list-numbers' AS icon,
       'cyan' AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Status' AS title,
       CASE WHEN i.status = 'pending_review' THEN 'Pending'
            WHEN i.status = 'validated' THEN 'Validated'
            WHEN i.status = 'rejected' THEN 'Rejected'
       END AS value,
       CASE WHEN i.status = 'validated' THEN 'circle-check'
            WHEN i.status = 'rejected' THEN 'circle-x'
            ELSE 'clock' END AS icon,
       CASE WHEN i.status = 'validated' THEN 'green'
            WHEN i.status = 'rejected' THEN 'red'
            ELSE 'orange' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Formulaire combiné header + lignes ─────────────────────────────────────

SELECT 'form' AS component,
       'POST' AS method,
       'save_review.sql' AS action,
       'Save Changes' AS validate,
       'device-floppy' AS validate_icon,
       'green' AS validate_color,
       'Reset' AS reset,
       'Review & Edit' AS title,
       'review-form' AS id;

SELECT 'hidden' AS type, 'id' AS name, $id AS value;

-- Invoice header fields (with warning styling for low confidence)

SELECT 'text' AS type, 'invoice_number' AS name, 'Invoice Number' AS label,
       i.invoice_number AS value, TRUE AS required, 4 AS width,
       CASE WHEN COALESCE(i.invoice_number_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'document_type' AS name, 'Document Type' AS label,
       i.document_type AS value, 4 AS width,
       CASE WHEN COALESCE(i.document_type_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'date' AS type, 'issue_date' AS name, 'Issue Date' AS label,
       i.issue_date::TEXT AS value, 4 AS width,
       CASE WHEN COALESCE(i.issue_date_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'date' AS type, 'due_date' AS name, 'Due Date' AS label,
       i.due_date::TEXT AS value, 4 AS width,
       CASE WHEN COALESCE(i.due_date_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'supplier_name' AS name, 'Supplier Name' AS label,
       i.supplier_name AS value, 'building' AS prefix_icon, 4 AS width,
       CASE WHEN COALESCE(i.supplier_name_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'supplier_vat_id' AS name, 'Supplier VAT ID' AS label,
       i.supplier_vat_id AS value, 4 AS width,
       CASE WHEN COALESCE(i.supplier_vat_id_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'textarea' AS type, 'supplier_address' AS name, 'Supplier Address' AS label,
       i.supplier_address AS value, 2 AS rows, 4 AS width,
       CASE WHEN COALESCE(i.supplier_address_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'customer_name' AS name, 'Customer Name' AS label,
       i.customer_name AS value, 'user' AS prefix_icon, 4 AS width,
       CASE WHEN COALESCE(i.customer_name_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'textarea' AS type, 'customer_address' AS name, 'Customer Address' AS label,
       i.customer_address AS value, 2 AS rows, 4 AS width,
       CASE WHEN COALESCE(i.customer_address_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'number' AS type, 'total_amount' AS name, 'Total Amount (TTC)' AS label,
       i.total_amount::TEXT AS value, 0.01 AS step, 4 AS width,
       CASE WHEN COALESCE(i.total_amount_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'number' AS type, 'total_ht' AS name, 'Total HT' AS label,
       i.total_ht::TEXT AS value, 0.01 AS step, 4 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'number' AS type, 'tva_amount' AS name, 'TVA Amount' AS label,
       i.tva_amount::TEXT AS value, 0.01 AS step, 2 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'currency' AS name, 'Currency' AS label,
       i.currency AS value, 2 AS width, 3 AS maxlength
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'select' AS type, 'status' AS name, 'Status' AS label,
       i.status AS value, 2 AS width,
       '[{"label":"Pending Review","value":"pending_review"},{"label":"Validated","value":"validated"},{"label":"Rejected","value":"rejected"}]' AS options
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── LMNP fields (with auto-categorisation) ───────────────────────────────

SELECT 'divider' AS component, 'LMNP' AS contents;

-- Auto-suggest property from supplier_mapping
SET _auto_property = (
    SELECT sm.property_id::TEXT
      FROM accounting.supplier_mapping sm
      JOIN accounting.invoice i ON i.id = $id::INT
     WHERE i.supplier_name ILIKE '%' || sm.supplier_pattern || '%'
       AND i.property_id IS NULL
     LIMIT 1
);

-- Auto-suggest category from supplier_mapping
SET _auto_category = (
    SELECT sm.category_code
      FROM accounting.supplier_mapping sm
      JOIN accounting.invoice i ON i.id = $id::INT
     WHERE i.supplier_name ILIKE '%' || sm.supplier_pattern || '%'
       AND i.category_code IS NULL
     LIMIT 1
);

SELECT 'select' AS type, 'property_id' AS name, 'Property' AS label,
       COALESCE(i.property_id::TEXT, $_auto_property) AS value, 4 AS width, TRUE AS dropdown,
       CASE WHEN i.property_id IS NULL AND $_auto_property IS NOT NULL THEN 'Auto-suggested from supplier' END AS description,
       (SELECT json_agg(json_build_object('label', p.name || COALESCE(' — ' || p.city, ''), 'value', p.id))
          FROM accounting.property p)::TEXT AS options
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'select' AS type, 'category_code' AS name, 'Expense Category' AS label,
       COALESCE(i.category_code, $_auto_category) AS value, 4 AS width, TRUE AS dropdown,
       CASE WHEN i.category_code IS NULL AND $_auto_category IS NOT NULL THEN 'Auto-suggested from supplier' END AS description,
       (SELECT json_agg(json_build_object('label', c.label, 'value', c.code) ORDER BY c.sort_order)
          FROM accounting.expense_category c)::TEXT AS options
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'number' AS type, 'fiscal_year' AS name, 'Fiscal Year' AS label,
       COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date))::TEXT AS value,
       1 AS step, 2 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'textarea' AS type, 'notes' AS name, 'Notes' AS label,
       i.notes AS value, 3 AS rows, 12 AS width,
       'Internal notes, context, etc.' AS placeholder
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Line items (dynamic — handles any number) ────────────────────────────

SELECT 'divider' AS component, 'Line Items' AS contents;

-- Item count for the POST handler
SELECT 'hidden' AS type, 'item_count' AS name,
       (SELECT COUNT(*) FROM accounting.invoice_item
         WHERE invoice_number = i.invoice_number)::TEXT AS value
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- Dynamic rendering: CROSS JOIN each item with its field types
SELECT type, name, label, value, width, step, description, placeholder
FROM (
    SELECT
        CASE f.field_type
            WHEN 'desc'       THEN 'text'
            WHEN 'qty'        THEN 'number'
            WHEN 'price'      THEN 'number'
            WHEN 'item_total' THEN 'number'
            WHEN 'tva_rate'   THEN 'number'
        END AS type,
        f.field_type || '_' || it.item_index AS name,
        CASE f.field_type
            WHEN 'desc'       THEN 'Item ' || it.item_index || ' — Description'
            WHEN 'qty'        THEN 'Qty'
            WHEN 'price'      THEN 'Unit Price'
            WHEN 'item_total' THEN 'Total'
            WHEN 'tva_rate'   THEN 'TVA %'
        END AS label,
        CASE f.field_type
            WHEN 'desc'       THEN it.description
            WHEN 'qty'        THEN it.quantity::TEXT
            WHEN 'price'      THEN it.unit_price::TEXT
            WHEN 'item_total' THEN it.total::TEXT
            WHEN 'tva_rate'   THEN it.tva_rate::TEXT
        END AS value,
        CASE f.field_type
            WHEN 'desc'       THEN 4
            WHEN 'qty'        THEN 2
            WHEN 'price'      THEN 2
            WHEN 'item_total' THEN 2
            WHEN 'tva_rate'   THEN 2
        END AS width,
        CASE f.field_type
            WHEN 'desc'       THEN NULL::REAL
            WHEN 'qty'        THEN 0.001
            WHEN 'price'      THEN 0.01
            WHEN 'item_total' THEN 0.01
            WHEN 'tva_rate'   THEN 0.01
        END AS step,
        CASE WHEN f.field_type = 'desc' AND COALESCE(it.description_confidence, 0) < 0.5
             THEN 'Low confidence' END AS description,
        NULL AS placeholder,
        it.item_index * 10 + f.ord AS sort_ord
    FROM accounting.invoice_item it
    JOIN accounting.invoice i ON i.invoice_number = it.invoice_number AND i.id = $id::INT
    CROSS JOIN (VALUES
        ('desc', 1), ('qty', 2), ('price', 3), ('item_total', 4), ('tva_rate', 5)
    ) AS f(field_type, ord)
) items
ORDER BY sort_ord;

-- ── Navigation bottom ──────────────────────────────────────────────────────

SELECT 'button' AS component, 'center' AS justify, 'sm' AS size;

SELECT 'Previous' AS title,
       'arrow-left' AS icon,
       'review.sql?id=' || $_prev AS link,
       CASE WHEN $_prev IS NULL THEN TRUE END AS disabled
 WHERE $_total::INT > 0;

SELECT $_pos || ' / ' || $_total AS title,
       'list-numbers' AS icon,
       TRUE AS disabled
 WHERE $_total::INT > 0;

SELECT 'Next' AS title,
       'arrow-right' AS icon_after,
       'review.sql?id=' || $_next AS link,
       CASE WHEN $_next IS NULL THEN TRUE END AS disabled
 WHERE $_total::INT > 0;

-- ── Keyboard shortcuts legend ──────────────────────────────────────────────

SELECT 'text' AS component, TRUE AS center;
SELECT '**Alt+V** Validate  |  **Alt+R** Reject  |  **Alt+S** Save  |  **Alt+←/→** Navigate' AS contents_md;

-- ── Keyboard shortcuts (data attributes + static script) ─────────────────

SELECT 'html' AS component;
SELECT '<div id="review-shortcuts" style="display:none"'
    || CASE WHEN $_validate_link IS NOT NULL THEN ' data-validate="' || replace(replace($_validate_link, '&', '&amp;'), '"', '&quot;') || '"' ELSE '' END
    || CASE WHEN $_reject_link IS NOT NULL THEN ' data-reject="' || replace(replace($_reject_link, '&', '&amp;'), '"', '&quot;') || '"' ELSE '' END
    || CASE WHEN $_prev IS NOT NULL THEN ' data-prev="review.sql?id=' || $_prev || '"' ELSE '' END
    || CASE WHEN $_next IS NOT NULL THEN ' data-next="review.sql?id=' || $_next || '"' ELSE '' END
    || '></div>' AS html;

SELECT 'html' AS component;
SELECT '<script>
document.addEventListener("keydown", function(e) {
    if (e.target.matches("input, textarea, select")) return;
    if (!e.altKey) return;
    var d = document.getElementById("review-shortcuts");
    if (!d) return;
    switch (e.key) {
        case "v": case "V":
            e.preventDefault();
            if (d.dataset.validate) window.location.href = d.dataset.validate;
            break;
        case "r": case "R":
            e.preventDefault();
            if (d.dataset.reject) window.location.href = d.dataset.reject;
            break;
        case "s": case "S":
            e.preventDefault();
            var f = document.querySelector("form[action=''save_review.sql'']");
            if (f) f.submit();
            break;
        case "ArrowLeft":
            e.preventDefault();
            if (d.dataset.prev) window.location.href = d.dataset.prev;
            break;
        case "ArrowRight":
            e.preventDefault();
            if (d.dataset.next) window.location.href = d.dataset.next;
            break;
    }
});
</script>' AS html;
