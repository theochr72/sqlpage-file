-- invoices.sql — Liste des factures avec filtres

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── Tabs de statut rapide ────────────────────────────────────────────────────

SELECT 'tab' AS component, TRUE AS center;

SELECT 'All' AS title,
       'invoices.sql' AS link,
       ($status IS NULL OR $status = '') AS active,
       'list' AS icon;

SELECT 'Pending Review' AS title,
       'invoices.sql?status=pending_review' AS link,
       $status = 'pending_review' AS active,
       'clock' AS icon,
       'orange' AS color;

SELECT 'Validated' AS title,
       'invoices.sql?status=validated' AS link,
       $status = 'validated' AS active,
       'circle-check' AS icon,
       'green' AS color;

SELECT 'Rejected' AS title,
       'invoices.sql?status=rejected' AS link,
       $status = 'rejected' AS active,
       'circle-x' AS icon,
       'red' AS color;

-- ── Formulaire de filtres avancés ────────────────────────────────────────────

SELECT 'form' AS component,
       'GET' AS method,
       'invoices.sql' AS action,
       'Search' AS validate,
       'search' AS validate_icon,
       'azure' AS validate_color;

SELECT 'text' AS type, 'supplier' AS name, 'Supplier' AS label,
       $supplier AS value, 'building' AS prefix_icon, 3 AS width;

SELECT 'select' AS type, 'property' AS name, 'Property' AS label,
       $property AS value, 3 AS width, TRUE AS dropdown, TRUE AS empty_option,
       (SELECT json_agg(json_build_object('label', p.name, 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

SELECT 'date' AS type, 'date_from' AS name, 'From' AS label,
       $date_from AS value, 3 AS width;

SELECT 'date' AS type, 'date_to' AS name, 'To' AS label,
       $date_to AS value, 3 AS width;

-- ── Résumé filtré ────────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 4 AS columns;

SELECT 'Invoices' AS title,
       COUNT(*)::TEXT AS value,
       'file-invoice' AS icon
  FROM accounting.invoice i
 WHERE ($status IS NULL OR $status = '' OR i.status = $status)
   AND ($supplier IS NULL OR $supplier = '' OR i.supplier_name ILIKE '%' || $supplier || '%')
   AND ($date_from IS NULL OR $date_from = '' OR i.issue_date >= $date_from::DATE)
   AND ($date_to IS NULL OR $date_to = '' OR i.issue_date <= $date_to::DATE)
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Total Spend' AS title,
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999G999D00'), '0') AS value,
       'currency-euro' AS icon,
       'green' AS color
  FROM accounting.invoice i
 WHERE ($status IS NULL OR $status = '' OR i.status = $status)
   AND ($supplier IS NULL OR $supplier = '' OR i.supplier_name ILIKE '%' || $supplier || '%')
   AND ($date_from IS NULL OR $date_from = '' OR i.issue_date >= $date_from::DATE)
   AND ($date_to IS NULL OR $date_to = '' OR i.issue_date <= $date_to::DATE)
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Avg Confidence' AS title,
       COALESCE(ROUND(AVG(i.overall_confidence) * 100)::TEXT || '%', '-') AS value,
       'target' AS icon,
       CASE WHEN AVG(i.overall_confidence) >= 0.8 THEN 'green'
            WHEN AVG(i.overall_confidence) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i
 WHERE ($status IS NULL OR $status = '' OR i.status = $status)
   AND ($supplier IS NULL OR $supplier = '' OR i.supplier_name ILIKE '%' || $supplier || '%')
   AND ($date_from IS NULL OR $date_from = '' OR i.issue_date >= $date_from::DATE)
   AND ($date_to IS NULL OR $date_to = '' OR i.issue_date <= $date_to::DATE)
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Suppliers' AS title,
       COUNT(DISTINCT i.supplier_name)::TEXT AS value,
       'building' AS icon,
       'cyan' AS color
  FROM accounting.invoice i
 WHERE ($status IS NULL OR $status = '' OR i.status = $status)
   AND ($supplier IS NULL OR $supplier = '' OR i.supplier_name ILIKE '%' || $supplier || '%')
   AND ($date_from IS NULL OR $date_from = '' OR i.issue_date >= $date_from::DATE)
   AND ($date_to IS NULL OR $date_to = '' OR i.issue_date <= $date_to::DATE)
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

-- ── Tableau des factures ─────────────────────────────────────────────────────

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS search,
       'Confidence,Amount' AS align_right,
       TRUE AS hover,
       TRUE AS striped_rows,
       TRUE AS small,
       'No invoices found matching your filters.' AS empty_description;

SELECT i.invoice_number AS "Invoice #",
       i.supplier_name AS "Supplier",
       i.issue_date::TEXT AS "Date",
       COALESCE(i.total_amount::TEXT || ' ' || COALESCE(i.currency, ''), '') AS "Amount",
       COALESCE(c.label, '') AS "Category",
       COALESCE(p.name, '') AS "Property",
       COALESCE(ROUND(i.overall_confidence * 100)::TEXT || '%', '-') AS "Confidence",
       CASE WHEN i.status = 'pending_review' THEN 'Pending'
            WHEN i.status = 'validated' THEN 'Validated'
            WHEN i.status = 'rejected' THEN 'Rejected'
       END AS "Status",
       CASE WHEN i.status = 'validated' THEN 'green'
            WHEN i.status = 'rejected' THEN 'red'
            WHEN i.overall_confidence < 0.5 THEN 'red'
            WHEN i.overall_confidence < 0.8 THEN 'yellow'
            ELSE NULL END AS _sqlpage_color,
       'invoice.sql?id=' || i.id AS _sqlpage_id
  FROM accounting.invoice i
  LEFT JOIN accounting.expense_category c ON c.code = i.category_code
  LEFT JOIN accounting.property p ON p.id = i.property_id
 WHERE ($status IS NULL OR $status = '' OR i.status = $status)
   AND ($supplier IS NULL OR $supplier = '' OR i.supplier_name ILIKE '%' || $supplier || '%')
   AND ($date_from IS NULL OR $date_from = '' OR i.issue_date >= $date_from::DATE)
   AND ($date_to IS NULL OR $date_to = '' OR i.issue_date <= $date_to::DATE)
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)
 ORDER BY i.issue_date DESC NULLS LAST;
