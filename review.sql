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

SELECT 'button' AS component, 'end' AS justify, 'sm' AS size;

SELECT 'Validate' AS title,
       'green' AS color,
       'circle-check' AS icon,
       'update_status.sql?id=' || $id || '&status=validated&return=review&next=' || COALESCE($_next, '') AS link
  FROM accounting.invoice WHERE id = $id::INT;

SELECT 'Reject' AS title,
       'red' AS outline,
       'circle-x' AS icon,
       'update_status.sql?id=' || $id || '&status=rejected&return=review&next=' || COALESCE($_next, '') AS link
  FROM accounting.invoice WHERE id = $id::INT;

SELECT 'Detail' AS title,
       'file-text' AS icon,
       'azure' AS outline,
       'invoice.sql?id=' || $id AS link
  FROM accounting.invoice WHERE id = $id::INT;

-- ── PDF embed ──────────────────────────────────────────────────────────────

SELECT 'card' AS component, 1 AS columns;

SELECT i.supplier_name || ' — ' || i.invoice_number AS title,
       'serve_pdf.sql?id=' || $id AS embed,
       'iframe' AS embed_mode,
       'file-text' AS icon
  FROM accounting.invoice i
 WHERE i.id = $id::INT AND i.renamed_filename IS NOT NULL;

-- Fallback si pas de PDF
SELECT 'alert' AS component,
       'No PDF available' AS title,
       'file-off' AS icon,
       'orange' AS color,
       'The original PDF file was not found for this invoice.' AS description
  FROM accounting.invoice i
 WHERE i.id = $id::INT AND i.renamed_filename IS NULL;

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
       'Review & Edit' AS title;

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

SELECT 'number' AS type, 'total_amount' AS name, 'Total Amount' AS label,
       i.total_amount::TEXT AS value, 0.01 AS step, 4 AS width,
       CASE WHEN COALESCE(i.total_amount_confidence, 0) < 0.5 THEN 'Low confidence' END AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'currency' AS name, 'Currency' AS label,
       i.currency AS value, 2 AS width, 3 AS maxlength
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'select' AS type, 'status' AS name, 'Status' AS label,
       i.status AS value, 2 AS width,
       '[{"label":"Pending Review","value":"pending_review"},{"label":"Validated","value":"validated"},{"label":"Rejected","value":"rejected"}]' AS options
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── LMNP fields ────────────────────────────────────────────────────────────

SELECT 'divider' AS component, 'LMNP' AS contents;

SELECT 'select' AS type, 'property_id' AS name, 'Property' AS label,
       i.property_id::TEXT AS value, 4 AS width, TRUE AS dropdown,
       (SELECT json_agg(json_build_object('label', p.name || COALESCE(' — ' || p.city, ''), 'value', p.id))
          FROM accounting.property p)::TEXT AS options
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'select' AS type, 'category_code' AS name, 'Expense Category' AS label,
       i.category_code AS value, 4 AS width, TRUE AS dropdown,
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

-- ── Line items ─────────────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Line Items' AS contents;

-- Item count for the POST handler
SELECT 'hidden' AS type, 'item_count' AS name,
       (SELECT COUNT(*) FROM accounting.invoice_item
         WHERE invoice_number = i.invoice_number)::TEXT AS value
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- Each line item rendered as indexed fields via UNION ALL
SELECT type, name, label, value, width, step, description, placeholder, sort_ord
FROM (
    -- Item 1
    SELECT 'text' AS type, 'desc_1' AS name, 'Item 1 — Description' AS label,
           it.description AS value, 6 AS width, NULL::REAL AS step,
           CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END AS description,
           NULL AS placeholder, (it.item_index * 10 + 1) AS sort_ord
      FROM accounting.invoice_item it
      JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 1
    UNION ALL
    SELECT 'number', 'qty_1', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 1
    UNION ALL
    SELECT 'number', 'price_1', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 1
    UNION ALL
    SELECT 'number', 'item_total_1', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 1
    UNION ALL
    -- Item 2
    SELECT 'text', 'desc_2', 'Item 2 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 2
    UNION ALL
    SELECT 'number', 'qty_2', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 2
    UNION ALL
    SELECT 'number', 'price_2', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 2
    UNION ALL
    SELECT 'number', 'item_total_2', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 2
    UNION ALL
    -- Item 3
    SELECT 'text', 'desc_3', 'Item 3 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 3
    UNION ALL
    SELECT 'number', 'qty_3', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 3
    UNION ALL
    SELECT 'number', 'price_3', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 3
    UNION ALL
    SELECT 'number', 'item_total_3', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 3
    UNION ALL
    -- Item 4
    SELECT 'text', 'desc_4', 'Item 4 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 4
    UNION ALL
    SELECT 'number', 'qty_4', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 4
    UNION ALL
    SELECT 'number', 'price_4', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 4
    UNION ALL
    SELECT 'number', 'item_total_4', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 4
    UNION ALL
    -- Item 5
    SELECT 'text', 'desc_5', 'Item 5 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 5
    UNION ALL
    SELECT 'number', 'qty_5', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 5
    UNION ALL
    SELECT 'number', 'price_5', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 5
    UNION ALL
    SELECT 'number', 'item_total_5', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 5
    UNION ALL
    -- Item 6
    SELECT 'text', 'desc_6', 'Item 6 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 6
    UNION ALL
    SELECT 'number', 'qty_6', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 6
    UNION ALL
    SELECT 'number', 'price_6', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 6
    UNION ALL
    SELECT 'number', 'item_total_6', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 6
    UNION ALL
    -- Item 7
    SELECT 'text', 'desc_7', 'Item 7 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 7
    UNION ALL
    SELECT 'number', 'qty_7', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 7
    UNION ALL
    SELECT 'number', 'price_7', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 7
    UNION ALL
    SELECT 'number', 'item_total_7', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 7
    UNION ALL
    -- Item 8
    SELECT 'text', 'desc_8', 'Item 8 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 8
    UNION ALL
    SELECT 'number', 'qty_8', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 8
    UNION ALL
    SELECT 'number', 'price_8', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 8
    UNION ALL
    SELECT 'number', 'item_total_8', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 8
    UNION ALL
    -- Item 9
    SELECT 'text', 'desc_9', 'Item 9 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 9
    UNION ALL
    SELECT 'number', 'qty_9', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 9
    UNION ALL
    SELECT 'number', 'price_9', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 9
    UNION ALL
    SELECT 'number', 'item_total_9', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 9
    UNION ALL
    -- Item 10
    SELECT 'text', 'desc_10', 'Item 10 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 10
    UNION ALL
    SELECT 'number', 'qty_10', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 10
    UNION ALL
    SELECT 'number', 'price_10', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 10
    UNION ALL
    SELECT 'number', 'item_total_10', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 10
    UNION ALL
    -- Item 11
    SELECT 'text', 'desc_11', 'Item 11 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 11
    UNION ALL
    SELECT 'number', 'qty_11', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 11
    UNION ALL
    SELECT 'number', 'price_11', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 11
    UNION ALL
    SELECT 'number', 'item_total_11', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 11
    UNION ALL
    -- Item 12
    SELECT 'text', 'desc_12', 'Item 12 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 12
    UNION ALL
    SELECT 'number', 'qty_12', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 12
    UNION ALL
    SELECT 'number', 'price_12', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 12
    UNION ALL
    SELECT 'number', 'item_total_12', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 12
    UNION ALL
    -- Item 13
    SELECT 'text', 'desc_13', 'Item 13 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 13
    UNION ALL
    SELECT 'number', 'qty_13', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 13
    UNION ALL
    SELECT 'number', 'price_13', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 13
    UNION ALL
    SELECT 'number', 'item_total_13', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 13
    UNION ALL
    -- Item 14
    SELECT 'text', 'desc_14', 'Item 14 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 14
    UNION ALL
    SELECT 'number', 'qty_14', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 14
    UNION ALL
    SELECT 'number', 'price_14', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 14
    UNION ALL
    SELECT 'number', 'item_total_14', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 14
    UNION ALL
    -- Item 15
    SELECT 'text', 'desc_15', 'Item 15 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 15
    UNION ALL
    SELECT 'number', 'qty_15', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 15
    UNION ALL
    SELECT 'number', 'price_15', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 15
    UNION ALL
    SELECT 'number', 'item_total_15', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 15
    UNION ALL
    -- Item 16
    SELECT 'text', 'desc_16', 'Item 16 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 16
    UNION ALL
    SELECT 'number', 'qty_16', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 16
    UNION ALL
    SELECT 'number', 'price_16', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 16
    UNION ALL
    SELECT 'number', 'item_total_16', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 16
    UNION ALL
    -- Item 17
    SELECT 'text', 'desc_17', 'Item 17 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 17
    UNION ALL
    SELECT 'number', 'qty_17', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 17
    UNION ALL
    SELECT 'number', 'price_17', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 17
    UNION ALL
    SELECT 'number', 'item_total_17', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 17
    UNION ALL
    -- Item 18
    SELECT 'text', 'desc_18', 'Item 18 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 18
    UNION ALL
    SELECT 'number', 'qty_18', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 18
    UNION ALL
    SELECT 'number', 'price_18', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 18
    UNION ALL
    SELECT 'number', 'item_total_18', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 18
    UNION ALL
    -- Item 19
    SELECT 'text', 'desc_19', 'Item 19 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 19
    UNION ALL
    SELECT 'number', 'qty_19', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 19
    UNION ALL
    SELECT 'number', 'price_19', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 19
    UNION ALL
    SELECT 'number', 'item_total_19', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 19
    UNION ALL
    -- Item 20
    SELECT 'text', 'desc_20', 'Item 20 — Description', it.description, 6, NULL, CASE WHEN COALESCE(it.description_confidence, 0) < 0.5 THEN 'Low confidence' END, NULL, (it.item_index * 10 + 1)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 20
    UNION ALL
    SELECT 'number', 'qty_20', 'Qty', it.quantity::TEXT, 2, 0.001, NULL, NULL, (it.item_index * 10 + 2)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 20
    UNION ALL
    SELECT 'number', 'price_20', 'Unit Price', it.unit_price::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 3)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 20
    UNION ALL
    SELECT 'number', 'item_total_20', 'Total', it.total::TEXT, 2, 0.01, NULL, NULL, (it.item_index * 10 + 4)
      FROM accounting.invoice_item it JOIN accounting.invoice i ON i.invoice_number = it.invoice_number
     WHERE i.id = $id::INT AND it.item_index = 20
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
