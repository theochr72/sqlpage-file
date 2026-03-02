-- invoices.sql — Liste des factures avec filtres

SELECT 'shell' AS component,
       'Invoices' AS title,
       'file-invoice' AS icon,
       'Dashboard' AS menu_item,
       '/' AS link,
       'Invoices' AS menu_item,
       '/invoices.sql' AS link;

-- ── Formulaire de filtres ────────────────────────────────────────────────────

SELECT 'form' AS component,
       'GET' AS method,
       'invoices.sql' AS action,
       'Filter' AS validate,
       'filter' AS validate_icon;

SELECT 'select' AS type, 'status' AS name, 'Status' AS label,
       $status AS value, TRUE AS dropdown,
       '[{"label":"Pending Review","value":"pending_review"},{"label":"Validated","value":"validated"},{"label":"Rejected","value":"rejected"}]' AS options,
       3 AS width;

SELECT 'text' AS type, 'supplier' AS name, 'Supplier' AS label,
       $supplier AS value, 'search' AS prefix_icon, 3 AS width;

SELECT 'date' AS type, 'date_from' AS name, 'From' AS label,
       $date_from AS value, 3 AS width;

SELECT 'date' AS type, 'date_to' AS name, 'To' AS label,
       $date_to AS value, 3 AS width;

-- ── Tableau des factures ─────────────────────────────────────────────────────

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS search,
       'Confidence' AS align_right,
       'Amount' AS align_right,
       TRUE AS hover,
       TRUE AS striped_rows,
       'No invoices found.' AS empty_description;

SELECT i.invoice_number AS "Invoice #",
       i.supplier_name AS "Supplier",
       i.issue_date::TEXT AS "Date",
       COALESCE(i.total_amount::TEXT || ' ' || COALESCE(i.currency, ''), '') AS "Amount",
       COALESCE(ROUND(i.overall_confidence * 100)::TEXT || '%', 'N/A') AS "Confidence",
       i.status AS "Status",
       CASE WHEN i.overall_confidence >= 0.8 THEN 'green'
            WHEN i.overall_confidence >= 0.5 THEN 'yellow'
            ELSE 'red' END AS _sqlpage_color,
       'invoice.sql?id=' || i.id AS _sqlpage_id
  FROM accounting.invoice i
 WHERE ($status IS NULL OR $status = '' OR i.status = $status)
   AND ($supplier IS NULL OR $supplier = '' OR i.supplier_name ILIKE '%' || $supplier || '%')
   AND ($date_from IS NULL OR $date_from = '' OR i.issue_date >= $date_from::DATE)
   AND ($date_to IS NULL OR $date_to = '' OR i.issue_date <= $date_to::DATE)
 ORDER BY i.issue_date DESC NULLS LAST;
