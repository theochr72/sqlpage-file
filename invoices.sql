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

SELECT 'select' AS type, 'supplier' AS name, 'Supplier' AS label,
       $supplier AS value, 3 AS width, TRUE AS dropdown, TRUE AS searchable, TRUE AS empty_option,
       (SELECT json_agg(json_build_object('label', s.supplier_name, 'value', s.supplier_name) ORDER BY s.supplier_name)
          FROM (SELECT DISTINCT supplier_name FROM accounting.invoice WHERE supplier_name IS NOT NULL) s)::TEXT AS options;

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
   AND ($supplier IS NULL OR $supplier = '' OR i.supplier_name = $supplier)
   AND ($date_from IS NULL OR $date_from = '' OR i.issue_date >= $date_from::DATE)
   AND ($date_to IS NULL OR $date_to = '' OR i.issue_date <= $date_to::DATE)
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Total Spend' AS title,
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999G999D00'), '0') AS value,
       'currency-euro' AS icon,
       'green' AS color
  FROM accounting.invoice i
 WHERE ($status IS NULL OR $status = '' OR i.status = $status)
   AND ($supplier IS NULL OR $supplier = '' OR i.supplier_name = $supplier)
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
   AND ($supplier IS NULL OR $supplier = '' OR i.supplier_name = $supplier)
   AND ($date_from IS NULL OR $date_from = '' OR i.issue_date >= $date_from::DATE)
   AND ($date_to IS NULL OR $date_to = '' OR i.issue_date <= $date_to::DATE)
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Suppliers' AS title,
       COUNT(DISTINCT i.supplier_name)::TEXT AS value,
       'building' AS icon,
       'cyan' AS color
  FROM accounting.invoice i
 WHERE ($status IS NULL OR $status = '' OR i.status = $status)
   AND ($supplier IS NULL OR $supplier = '' OR i.supplier_name = $supplier)
   AND ($date_from IS NULL OR $date_from = '' OR i.issue_date >= $date_from::DATE)
   AND ($date_to IS NULL OR $date_to = '' OR i.issue_date <= $date_to::DATE)
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

-- ── Bulk actions (pending_review only) ──────────────────────────────────────

SELECT 'button' AS component, 'end' AS justify, 'sm' AS size
 WHERE $status = 'pending_review';

SELECT 'Validate All (≥80%)' AS title,
       'green' AS color,
       'checks' AS icon,
       'bulk_status.sql?action=validate&min_confidence=0.8' AS link
 WHERE $status = 'pending_review'
   AND EXISTS (SELECT 1 FROM accounting.invoice WHERE status = 'pending_review' AND overall_confidence >= 0.8);

SELECT 'Reject All (< 20%)' AS title,
       'red' AS outline,
       'circle-x' AS icon,
       'bulk_status.sql?action=reject&max_confidence=0.2' AS link
 WHERE $status = 'pending_review'
   AND EXISTS (SELECT 1 FROM accounting.invoice WHERE status = 'pending_review' AND overall_confidence < 0.2);

-- ── Tableau des factures ─────────────────────────────────────────────────────

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS search,
       'Confidence,Amount' AS align_right,
       TRUE AS hover,
       TRUE AS striped_rows,
       TRUE AS small,
       'No invoices found matching your filters.' AS empty_description;

SELECT v.invoice_number AS "Invoice #",
       v.supplier_name AS "Supplier",
       v.issue_date::TEXT AS "Date",
       COALESCE(v.total_amount::TEXT || ' ' || COALESCE(v.currency, ''), '') AS "Amount",
       v.category_label AS "Category",
       v.property_name AS "Property",
       COALESCE(ROUND(v.overall_confidence * 100)::TEXT || '%', '-') AS "Confidence",
       v.status_label AS "Status",
       CASE WHEN v.status = 'validated' THEN 'green'
            WHEN v.status = 'rejected' THEN 'red'
            WHEN v.overall_confidence < 0.5 THEN 'red'
            WHEN v.overall_confidence < 0.8 THEN 'yellow'
            ELSE NULL END AS _sqlpage_color,
       'invoice.sql?id=' || v.id AS _sqlpage_id
  FROM accounting.vw_invoice_summary v
 WHERE ($status IS NULL OR $status = '' OR v.status = $status)
   AND ($supplier IS NULL OR $supplier = '' OR v.supplier_name = $supplier)
   AND ($date_from IS NULL OR $date_from = '' OR v.issue_date >= $date_from::DATE)
   AND ($date_to IS NULL OR $date_to = '' OR v.issue_date <= $date_to::DATE)
   AND ($property IS NULL OR $property = '' OR v.property_id = $property::INT)
 ORDER BY v.issue_date DESC NULLS LAST;
