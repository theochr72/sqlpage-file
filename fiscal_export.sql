-- fiscal_export.sql — Export CSV des dépenses d'une année fiscale

SET _year = COALESCE(NULLIF($year, ''), EXTRACT(YEAR FROM CURRENT_DATE)::TEXT);

SELECT 'csv' AS component,
       'lmnp_expenses_' || $_year AS filename,
       'LMNP Expenses ' || $_year AS title;

SELECT v.invoice_number AS "Invoice #",
       v.issue_date::TEXT AS "Date",
       v.supplier_name AS "Supplier",
       v.category_label AS "Category",
       v.property_name AS "Property",
       v.total_amount AS "Amount TTC",
       v.total_ht AS "Amount HT",
       v.tva_amount AS "TVA",
       COALESCE(v.currency, 'EUR') AS "Currency",
       CASE WHEN v.category_deductible THEN 'Yes' ELSE 'No' END AS "Deductible",
       v.status_label AS "Status",
       COALESCE(ROUND(v.overall_confidence * 100)::TEXT || '%', '') AS "Confidence",
       v.notes AS "Notes"
  FROM accounting.vw_invoice_summary v
 WHERE COALESCE(v.fiscal_year, EXTRACT(YEAR FROM v.issue_date)::INT) = $_year::INT
   AND ($property IS NULL OR $property = '' OR v.property_id = $property::INT)
 ORDER BY v.issue_date, v.invoice_number;
