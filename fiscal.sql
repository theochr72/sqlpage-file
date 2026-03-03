-- fiscal.sql — Recapitulatif fiscal LMNP par annee et categorie

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'hero' AS component,
       'Recapitulatif fiscal' AS title,
       'Vue d''ensemble des depenses LMNP par annee, categorie et bien.' AS description;

-- ── Sélecteur d'année et bien ────────────────────────────────────────────────

SELECT 'form' AS component,
       'GET' AS method,
       'fiscal.sql' AS action,
       'Filtrer' AS validate,
       'filter' AS validate_icon,
       'azure' AS validate_color;

SELECT 'select' AS type, 'year' AS name, 'Annee fiscale' AS label,
       COALESCE($year, EXTRACT(YEAR FROM CURRENT_DATE)::TEXT) AS value,
       4 AS width, TRUE AS dropdown,
       (SELECT json_agg(json_build_object('label', y::TEXT, 'value', y::TEXT) ORDER BY y DESC)
          FROM (SELECT DISTINCT COALESCE(fiscal_year, EXTRACT(YEAR FROM issue_date)::INT) AS y
                  FROM accounting.invoice WHERE issue_date IS NOT NULL OR fiscal_year IS NOT NULL) sub
       )::TEXT AS options;

SELECT 'select' AS type, 'property' AS name, 'Bien' AS label,
       $property AS value, 4 AS width, TRUE AS dropdown, TRUE AS empty_option,
       (SELECT json_agg(json_build_object('label', p.name, 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

-- Variable d'année courante
SET _year = COALESCE(NULLIF($year, ''), EXTRACT(YEAR FROM CURRENT_DATE)::TEXT);

-- ── KPIs de l'année ──────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 5 AS columns;

SELECT 'Total depenses' AS title,
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00'), '0') AS value,
       'EUR' AS unit,
       'currency-euro' AS icon,
       'green' AS color
  FROM accounting.invoice i
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Factures' AS title,
       COUNT(*)::TEXT AS value,
       'file-invoice' AS icon,
       'azure' AS color
  FROM accounting.invoice i
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Deductible' AS title,
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00'), '0') AS value,
       'EUR' AS unit,
       'receipt-tax' AS icon,
       'cyan' AS color
  FROM accounting.invoice i
  JOIN accounting.expense_category c ON c.code = i.category_code
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND c.deductible = TRUE
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Total TVA' AS title,
       COALESCE(to_char(SUM(i.tva_amount), 'FM999G999D00'), '0') AS value,
       'EUR' AS unit,
       'receipt-tax' AS icon,
       'purple' AS color
  FROM accounting.invoice i
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Non categorisees' AS title,
       COUNT(*)::TEXT AS value,
       'alert-triangle' AS icon,
       CASE WHEN COUNT(*) > 0 THEN 'orange' ELSE 'green' END AS color
  FROM accounting.invoice i
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND i.category_code IS NULL
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

-- ── Tableau par catégorie ────────────────────────────────────────────────────

SELECT 'title' AS component,
       'Depenses par categorie — ' || $_year AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort,
       'Montant,Factures' AS align_right,
       TRUE AS hover,
       TRUE AS striped_rows,
       'Aucune depense categorisee pour cette annee.' AS empty_description;

SELECT c.label AS "Categorie",
       COUNT(i.id)::TEXT AS "Factures",
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00'), '0') || ' EUR' AS "Montant",
       CASE WHEN c.deductible THEN 'Oui' ELSE 'Non' END AS "Deductible"
  FROM accounting.expense_category c
  LEFT JOIN accounting.invoice i
    ON i.category_code = c.code
   AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)
 GROUP BY c.code, c.label, c.deductible, c.sort_order
HAVING COUNT(i.id) > 0
 ORDER BY c.sort_order;

-- ── Chart: Répartition par catégorie (pie) ───────────────────────────────────

SELECT 'chart' AS component,
       'Repartition des depenses' AS title,
       'pie' AS type,
       TRUE AS labels,
       350 AS height;

SELECT c.label AS x,
       COALESCE(SUM(i.total_amount)::REAL, 0) AS y
  FROM accounting.expense_category c
  JOIN accounting.invoice i ON i.category_code = c.code
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)
 GROUP BY c.label, c.sort_order
 ORDER BY c.sort_order;

-- ── Chart: Dépenses par mois (bar) ──────────────────────────────────────────

SELECT 'chart' AS component,
       'Depenses mensuelles — ' || $_year AS title,
       'bar' AS type,
       TRUE AS labels,
       TRUE AS toolbar,
       350 AS height;

SELECT to_char(i.issue_date, 'MM') AS x,
       ROUND(SUM(i.total_amount)::NUMERIC, 2) AS y,
       'Depenses' AS series
  FROM accounting.invoice i
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND i.issue_date IS NOT NULL
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)
 GROUP BY to_char(i.issue_date, 'MM')
 ORDER BY x;

-- ── Tableau par bien (si multi-biens) ────────────────────────────────────────

SELECT 'title' AS component,
       'Depenses par bien — ' || $_year AS contents,
       3 AS level
 WHERE $property IS NULL OR $property = '';

SELECT 'table' AS component,
       TRUE AS sort,
       'Montant,Factures' AS align_right,
       TRUE AS hover,
       TRUE AS striped_rows,
       'Aucune depense assignee a un bien.' AS empty_description
 WHERE $property IS NULL OR $property = '';

SELECT p.name AS "Bien",
       p.city AS "Ville",
       COUNT(i.id)::TEXT AS "Factures",
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00'), '0') || ' EUR' AS "Montant"
  FROM accounting.property p
  LEFT JOIN accounting.invoice i
    ON i.property_id = p.id
   AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
 WHERE ($property IS NULL OR $property = '')
 GROUP BY p.id, p.name, p.city
 ORDER BY SUM(i.total_amount) DESC NULLS LAST;

-- ── Factures non catégorisées ────────────────────────────────────────────────

SELECT 'title' AS component,
       'Factures non categorisees' AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS hover,
       'Montant' AS align_right,
       'Toutes les factures sont categorisees !' AS empty_description;

SELECT i.invoice_number AS "N° Facture",
       i.supplier_name AS "Fournisseur",
       i.issue_date::TEXT AS "Date",
       COALESCE(i.total_amount::TEXT || ' EUR', '') AS "Montant",
       'invoice.sql?id=' || i.id AS _sqlpage_id,
       'orange' AS _sqlpage_color
  FROM accounting.invoice i
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND i.category_code IS NULL
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)
 ORDER BY i.issue_date;

-- ── Export CSV ───────────────────────────────────────────────────────────────

SELECT 'button' AS component, 'center' AS justify;

SELECT 'Exporter en CSV' AS title,
       'download' AS icon,
       'green' AS color,
       'fiscal_export.sql?year=' || $_year
           || CASE WHEN $property IS NOT NULL AND $property != '' THEN '&property=' || $property ELSE '' END
       AS link;
