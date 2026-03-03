-- fiscal.sql — Récapitulatif fiscal LMNP par année et catégorie

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'hero' AS component,
       'Fiscal Summary' AS title,
       'LMNP expense overview by year, category, and property.' AS description;

-- ── Sélecteur d'année et bien ────────────────────────────────────────────────

SELECT 'form' AS component,
       'GET' AS method,
       'fiscal.sql' AS action,
       'Filter' AS validate,
       'filter' AS validate_icon,
       'azure' AS validate_color;

SELECT 'select' AS type, 'year' AS name, 'Fiscal Year' AS label,
       COALESCE($year, EXTRACT(YEAR FROM CURRENT_DATE)::TEXT) AS value,
       4 AS width, TRUE AS dropdown,
       (SELECT json_agg(json_build_object('label', y::TEXT, 'value', y::TEXT) ORDER BY y DESC)
          FROM (SELECT DISTINCT COALESCE(fiscal_year, EXTRACT(YEAR FROM issue_date)::INT) AS y
                  FROM accounting.invoice WHERE issue_date IS NOT NULL OR fiscal_year IS NOT NULL) sub
       )::TEXT AS options;

SELECT 'select' AS type, 'property' AS name, 'Property' AS label,
       $property AS value, 4 AS width, TRUE AS dropdown, TRUE AS empty_option,
       (SELECT json_agg(json_build_object('label', p.name, 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

-- Variable d'année courante
SET _year = COALESCE(NULLIF($year, ''), EXTRACT(YEAR FROM CURRENT_DATE)::TEXT);

-- ── KPIs de l'année ──────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 5 AS columns;

SELECT 'Total Expenses' AS title,
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00'), '0') AS value,
       'EUR' AS unit,
       'currency-euro' AS icon,
       'green' AS color
  FROM accounting.invoice i
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Invoices' AS title,
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

SELECT 'Uncategorized' AS title,
       COUNT(*)::TEXT AS value,
       'alert-triangle' AS icon,
       CASE WHEN COUNT(*) > 0 THEN 'orange' ELSE 'green' END AS color
  FROM accounting.invoice i
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND i.category_code IS NULL
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

-- ── Tableau par catégorie ────────────────────────────────────────────────────

SELECT 'title' AS component,
       'Expenses by Category — ' || $_year AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort,
       'Amount,Invoices' AS align_right,
       TRUE AS hover,
       TRUE AS striped_rows,
       'No categorized expenses for this year.' AS empty_description;

SELECT c.label AS "Category",
       COUNT(i.id)::TEXT AS "Invoices",
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00'), '0') || ' EUR' AS "Amount",
       CASE WHEN c.deductible THEN 'Yes' ELSE 'No' END AS "Deductible"
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
       'Expense Breakdown' AS title,
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
       'Monthly Expenses — ' || $_year AS title,
       'bar' AS type,
       TRUE AS labels,
       TRUE AS toolbar,
       350 AS height;

SELECT to_char(i.issue_date, 'MM') AS x,
       ROUND(SUM(i.total_amount)::NUMERIC, 2) AS y,
       'Expenses' AS series
  FROM accounting.invoice i
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND i.issue_date IS NOT NULL
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)
 GROUP BY to_char(i.issue_date, 'MM')
 ORDER BY x;

-- ── Tableau par bien (si multi-biens) ────────────────────────────────────────

SELECT 'title' AS component,
       'Expenses by Property — ' || $_year AS contents,
       3 AS level
 WHERE $property IS NULL OR $property = '';

SELECT 'table' AS component,
       TRUE AS sort,
       'Amount,Invoices' AS align_right,
       TRUE AS hover,
       TRUE AS striped_rows,
       'No property-assigned expenses.' AS empty_description
 WHERE $property IS NULL OR $property = '';

SELECT p.name AS "Property",
       p.city AS "City",
       COUNT(i.id)::TEXT AS "Invoices",
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00'), '0') || ' EUR' AS "Amount"
  FROM accounting.property p
  LEFT JOIN accounting.invoice i
    ON i.property_id = p.id
   AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
 WHERE ($property IS NULL OR $property = '')
 GROUP BY p.id, p.name, p.city
 ORDER BY SUM(i.total_amount) DESC NULLS LAST;

-- ── Factures non catégorisées ────────────────────────────────────────────────

SELECT 'title' AS component,
       'Uncategorized Invoices' AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS hover,
       'Amount' AS align_right,
       'All invoices are categorized!' AS empty_description;

SELECT i.invoice_number AS "Invoice #",
       i.supplier_name AS "Supplier",
       i.issue_date::TEXT AS "Date",
       COALESCE(i.total_amount::TEXT || ' EUR', '') AS "Amount",
       'invoice.sql?id=' || i.id AS _sqlpage_id,
       'orange' AS _sqlpage_color
  FROM accounting.invoice i
 WHERE COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND i.category_code IS NULL
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)
 ORDER BY i.issue_date;

-- ── Export CSV ───────────────────────────────────────────────────────────────

SELECT 'button' AS component, 'center' AS justify;

SELECT 'Export CSV' AS title,
       'download' AS icon,
       'green' AS color,
       'fiscal_export.sql?year=' || $_year
           || CASE WHEN $property IS NOT NULL AND $property != '' THEN '&property=' || $property ELSE '' END
       AS link;
