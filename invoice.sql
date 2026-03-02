-- invoice.sql — Détail d'une facture

SELECT 'shell' AS component,
       'InvoiceAI' AS title,
       'file-invoice' AS icon,
       TRUE AS sidebar,
       'Dashboard' AS menu_item, '/' AS link,
       'Invoices' AS menu_item, '/invoices.sql' AS link,
       'Fiscal' AS menu_item, '/fiscal.sql' AS link,
       'Properties' AS menu_item, '/properties.sql' AS link,
       'Upload' AS menu_item, '/upload.sql' AS link,
       'dark' AS theme,
       'Inter' AS font;

-- Redirect si pas d'id valide
SELECT 'redirect' AS component, 'invoices.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

-- ── Breadcrumb ───────────────────────────────────────────────────────────────

SELECT 'breadcrumb' AS component;

SELECT 'Dashboard' AS title, '/' AS link;
SELECT 'Invoices' AS title, '/invoices.sql' AS link;
SELECT i.invoice_number AS title, TRUE AS active
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Alerte si édité manuellement ──────────────────────────────────────────────

SELECT 'alert' AS component,
       'pencil' AS icon,
       'azure' AS color,
       'Manually edited on ' || to_char(i.manually_edited_at, 'YYYY-MM-DD HH24:MI') AS title,
       'Fields: ' || array_to_string(i.manually_edited_fields, ', ')
           || '. Re-extraction will not overwrite these changes unless --force is used.' AS description,
       TRUE AS dismissible
  FROM accounting.invoice i
 WHERE i.id = $id::INT AND i.manually_edited_at IS NOT NULL;

-- ── Status + actions (haut de page) ──────────────────────────────────────────

SELECT 'button' AS component, 'end' AS justify, 'sm' AS size;

SELECT 'Edit' AS title,
       'azure' AS color,
       'pencil' AS icon,
       'edit_invoice.sql?id=' || $id AS link
  FROM accounting.invoice WHERE id = $id::INT;

SELECT 'Validate' AS title,
       'green' AS color,
       'circle-check' AS icon,
       'update_status.sql?id=' || $id || '&status=validated' AS link
  FROM accounting.invoice WHERE id = $id::INT AND status != 'validated';

SELECT 'Reject' AS title,
       'red' AS outline,
       'circle-x' AS icon,
       'update_status.sql?id=' || $id || '&status=rejected' AS link
  FROM accounting.invoice WHERE id = $id::INT AND status != 'rejected';

SELECT 'Reset' AS title,
       'orange' AS outline,
       'clock' AS icon,
       'update_status.sql?id=' || $id || '&status=pending_review' AS link
  FROM accounting.invoice WHERE id = $id::INT AND status != 'pending_review';

-- ── KPIs de la facture ───────────────────────────────────────────────────────

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
       ROUND(COALESCE(i.overall_confidence, 0) * 100)::INT AS progress_percent,
       CASE WHEN i.overall_confidence >= 0.8 THEN 'green'
            WHEN i.overall_confidence >= 0.5 THEN 'orange'
            ELSE 'red' END AS progress_color
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

-- ── Informations fournisseur & client ────────────────────────────────────────

SELECT 'datagrid' AS component,
       'Supplier' AS title,
       'building' AS icon;

SELECT 'Name' AS title,
       COALESCE(i.supplier_name, 'N/A') AS description,
       CASE WHEN COALESCE(i.supplier_name_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.supplier_name_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'VAT ID' AS title,
       COALESCE(i.supplier_vat_id, 'N/A') AS description,
       CASE WHEN COALESCE(i.supplier_vat_id_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.supplier_vat_id_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Address' AS title,
       COALESCE(i.supplier_address, 'N/A') AS description,
       CASE WHEN COALESCE(i.supplier_address_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.supplier_address_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'datagrid' AS component,
       'Customer' AS title,
       'user' AS icon;

SELECT 'Name' AS title,
       COALESCE(i.customer_name, 'N/A') AS description,
       CASE WHEN COALESCE(i.customer_name_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.customer_name_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Address' AS title,
       COALESCE(i.customer_address, 'N/A') AS description,
       CASE WHEN COALESCE(i.customer_address_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.customer_address_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Détails de la facture ────────────────────────────────────────────────────

SELECT 'datagrid' AS component,
       'Invoice Details' AS title,
       'file-text' AS icon;

SELECT 'Invoice Number' AS title,
       i.invoice_number AS description,
       CASE WHEN COALESCE(i.invoice_number_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.invoice_number_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Document Type' AS title,
       COALESCE(i.document_type, 'N/A') AS description,
       CASE WHEN COALESCE(i.document_type_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.document_type_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Issue Date' AS title,
       COALESCE(i.issue_date::TEXT, 'N/A') AS description,
       CASE WHEN COALESCE(i.issue_date_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.issue_date_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Due Date' AS title,
       COALESCE(i.due_date::TEXT, 'N/A') AS description,
       CASE WHEN COALESCE(i.due_date_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.due_date_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Currency' AS title,
       COALESCE(i.currency, 'N/A') AS description,
       CASE WHEN COALESCE(i.currency_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.currency_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Fichiers & traitement ────────────────────────────────────────────────────

SELECT 'datagrid' AS component,
       'Processing Info' AS title,
       'settings' AS icon;

SELECT 'Original File' AS title,
       COALESCE(i.original_filename, 'N/A') AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Renamed File' AS title,
       COALESCE(i.renamed_filename, 'N/A') AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Processed At' AS title,
       to_char(i.processed_at, 'YYYY-MM-DD HH24:MI:SS') AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Lignes de facture ────────────────────────────────────────────────────────

SELECT 'title' AS component,
       'Line Items' AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort,
       'Quantity,Unit Price,Total,Desc Conf,Qty Conf,Price Conf,Total Conf' AS align_right,
       TRUE AS hover,
       TRUE AS striped_rows,
       'No line items extracted.' AS empty_description;

SELECT item_index AS "#",
       description AS "Description",
       quantity::TEXT AS "Quantity",
       unit_price::TEXT AS "Unit Price",
       total::TEXT AS "Total",
       COALESCE(ROUND(description_confidence * 100)::TEXT || '%', '-') AS "Desc Conf",
       COALESCE(ROUND(quantity_confidence * 100)::TEXT || '%', '-') AS "Qty Conf",
       COALESCE(ROUND(unit_price_confidence * 100)::TEXT || '%', '-') AS "Price Conf",
       COALESCE(ROUND(total_confidence * 100)::TEXT || '%', '-') AS "Total Conf"
  FROM accounting.invoice_item
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
 ORDER BY item_index;

-- ── Confidence par champ (chart radar-like) ──────────────────────────────────

SELECT 'chart' AS component,
       'Field Confidence Breakdown' AS title,
       'bar' AS type,
       TRUE AS horizontal,
       0 AS ymin,
       1 AS ymax,
       300 AS height;

SELECT x, y FROM (
    SELECT 'Invoice #' AS x, i.invoice_number_confidence AS y, 1 AS ord FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Doc Type', i.document_type_confidence, 2 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Issue Date', i.issue_date_confidence, 3 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Due Date', i.due_date_confidence, 4 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Supplier', i.supplier_name_confidence, 5 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'VAT ID', i.supplier_vat_id_confidence, 6 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Address', i.supplier_address_confidence, 7 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Customer', i.customer_name_confidence, 8 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Amount', i.total_amount_confidence, 9 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Currency', i.currency_confidence, 10 FROM accounting.invoice i WHERE i.id = $id::INT
) sub
WHERE y IS NOT NULL
ORDER BY ord;

-- ── Retour ───────────────────────────────────────────────────────────────────

SELECT 'button' AS component, 'start' AS justify;

SELECT 'Back to Invoices' AS title,
       'arrow-left' AS icon,
       'invoices.sql' AS link;
