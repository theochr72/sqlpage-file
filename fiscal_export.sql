-- fiscal_export.sql — Export CSV des dépenses d'une année fiscale

SET _year = COALESCE(NULLIF($year, ''), EXTRACT(YEAR FROM CURRENT_DATE)::TEXT);

SELECT 'csv' AS component,
       'lmnp_expenses_' || $_year AS filename,
       'LMNP Expenses ' || $_year AS title;

SELECT i.invoice_number AS "Invoice #",
       i.issue_date::TEXT AS "Date",
       i.supplier_name AS "Supplier",
       COALESCE(c.label, 'Uncategorized') AS "Category",
       COALESCE(p.name, 'Unassigned') AS "Property",
       i.total_amount AS "Amount",
       COALESCE(i.currency, 'EUR') AS "Currency",
       CASE WHEN c.deductible THEN 'Yes' ELSE 'No' END AS "Deductible",
       i.status AS "Status",
       COALESCE(ROUND(i.overall_confidence * 100)::TEXT || '%', '') AS "Confidence",
       i.notes AS "Notes"
  FROM accounting.invoice i
  LEFT JOIN accounting.expense_category c ON c.code = i.category_code
  LEFT JOIN accounting.property p ON p.id = i.property_id
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)
 ORDER BY i.issue_date, i.invoice_number;
