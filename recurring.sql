-- recurring.sql — Recurring expense templates

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'title' AS component, 'Recurring Expenses' AS contents, 2 AS level;

-- ── Current period ──────────────────────────────────────────────────────────

SET _cur_month = EXTRACT(MONTH FROM CURRENT_DATE)::TEXT;
SET _cur_year  = EXTRACT(YEAR FROM CURRENT_DATE)::TEXT;

-- ── Add template form ───────────────────────────────────────────────────────

SELECT 'form' AS component,
       'POST' AS method,
       'save_recurring.sql' AS action,
       'Add Template' AS validate,
       'plus' AS validate_icon,
       'azure' AS validate_color,
       'New Recurring Expense' AS title;

SELECT 'select' AS type, 'property_id' AS name, 'Property' AS label,
       TRUE AS required, 3 AS width, TRUE AS dropdown,
       (SELECT json_agg(json_build_object('label', p.name, 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

SELECT 'select' AS type, 'category_code' AS name, 'Category' AS label,
       3 AS width, TRUE AS dropdown, TRUE AS empty_option,
       (SELECT json_agg(json_build_object('label', c.label, 'value', c.code) ORDER BY c.sort_order)
          FROM accounting.expense_category c)::TEXT AS options;

SELECT 'text' AS type, 'supplier_name' AS name, 'Supplier' AS label, 3 AS width;

SELECT 'text' AS type, 'description' AS name, 'Description' AS label,
       TRUE AS required, 3 AS width;

SELECT 'number' AS type, 'amount' AS name, 'Amount (€)' AS label,
       TRUE AS required, 3 AS width, 0.01 AS step;

SELECT 'select' AS type, 'frequency' AS name, 'Frequency' AS label,
       3 AS width, TRUE AS dropdown,
       '[{"label":"Monthly","value":"monthly"},{"label":"Quarterly","value":"quarterly"},{"label":"Yearly","value":"yearly"}]' AS options;

-- ── Templates table ─────────────────────────────────────────────────────────

SELECT 'title' AS component, 'Templates' AS contents, 3 AS level;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Amount' AS align_right,
       'No recurring expense templates.' AS empty_description;

SELECT p.name AS "Property",
       COALESCE(c.label, '—') AS "Category",
       COALESCE(re.supplier_name, '—') AS "Supplier",
       re.description AS "Description",
       to_char(re.amount, 'FM999G999D00') || ' €' AS "Amount",
       INITCAP(re.frequency) AS "Frequency",
       CASE WHEN re.active THEN 'Yes' ELSE 'No' END AS "Active",
       CASE WHEN g.id IS NOT NULL THEN 'Generated' ELSE 'Pending' END AS "Current Period",
       CASE WHEN g.id IS NOT NULL THEN 'green' ELSE 'orange' END AS _sqlpage_color,
       CASE WHEN g.id IS NULL AND re.active
            THEN 'generate_recurring.sql?id=' || re.id
       END AS _sqlpage_id
  FROM accounting.recurring_expense re
  JOIN accounting.property p ON p.id = re.property_id
  LEFT JOIN accounting.expense_category c ON c.code = re.category_code
  LEFT JOIN accounting.recurring_expense_generation g
    ON g.recurring_expense_id = re.id
   AND g.period_year = $_cur_year::INT
   AND g.period_month = $_cur_month::INT
 ORDER BY p.name, re.description;
