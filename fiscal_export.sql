-- fiscal_export.sql — Export CSV des depenses d'une annee fiscale

SET _year = COALESCE(NULLIF($year, ''), EXTRACT(YEAR FROM CURRENT_DATE)::TEXT);

SELECT 'csv' AS component,
       'lmnp_depenses_' || $_year AS filename,
       'Depenses LMNP ' || $_year AS title;

SELECT v.invoice_number AS "N° Facture",
       v.issue_date::TEXT AS "Date",
       v.supplier_name AS "Fournisseur",
       v.category_label AS "Categorie",
       v.property_name AS "Bien",
       v.total_amount AS "Montant TTC",
       v.total_ht AS "Montant HT",
       v.tva_amount AS "TVA",
       COALESCE(v.currency, 'EUR') AS "Devise",
       CASE WHEN v.category_deductible THEN 'Oui' ELSE 'Non' END AS "Deductible",
       v.status_label AS "Statut",
       COALESCE(ROUND(v.overall_confidence * 100)::TEXT || '%', '') AS "Confiance",
       v.notes AS "Notes"
  FROM accounting.vw_invoice_summary v
 WHERE COALESCE(v.fiscal_year, EXTRACT(YEAR FROM v.issue_date)::INT) = $_year::INT
   AND ($property IS NULL OR $property = '' OR v.property_id = $property::INT)
 ORDER BY v.issue_date, v.invoice_number;
