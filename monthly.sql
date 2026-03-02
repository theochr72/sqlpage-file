-- monthly.sql — Monthly summary (rent vs expenses vs cash-flow)

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'title' AS component, 'Monthly Summary' AS contents, 2 AS level;

-- ── Filters ─────────────────────────────────────────────────────────────────

SET _year  = COALESCE(NULLIF($year, ''), EXTRACT(YEAR FROM CURRENT_DATE)::TEXT);
SET _month = COALESCE(NULLIF($month, ''), EXTRACT(MONTH FROM CURRENT_DATE)::TEXT);

SELECT 'form' AS component,
       'GET' AS method,
       'monthly.sql' AS action,
       'Filter' AS validate,
       'filter' AS validate_icon,
       'azure' AS validate_color;

SELECT 'select' AS type, 'month' AS name, 'Month' AS label,
       $_month AS value, 4 AS width, TRUE AS dropdown,
       '[{"label":"January","value":"1"},{"label":"February","value":"2"},{"label":"March","value":"3"},{"label":"April","value":"4"},{"label":"May","value":"5"},{"label":"June","value":"6"},{"label":"July","value":"7"},{"label":"August","value":"8"},{"label":"September","value":"9"},{"label":"October","value":"10"},{"label":"November","value":"11"},{"label":"December","value":"12"}]' AS options;

SELECT 'select' AS type, 'year' AS name, 'Year' AS label,
       $_year AS value, 4 AS width, TRUE AS dropdown,
       (SELECT json_agg(json_build_object('label', y::TEXT, 'value', y::TEXT) ORDER BY y DESC)
          FROM generate_series(
              EXTRACT(YEAR FROM CURRENT_DATE)::INT - 3,
              EXTRACT(YEAR FROM CURRENT_DATE)::INT + 1
          ) AS y
       )::TEXT AS options;

SELECT 'select' AS type, 'property' AS name, 'Property' AS label,
       $property AS value, 4 AS width, TRUE AS dropdown, TRUE AS empty_option,
       (SELECT json_agg(json_build_object('label', p.name, 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

-- ── KPIs ────────────────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 4 AS columns;

-- Rent expected
SELECT 'Rent Expected' AS title,
       COALESCE(to_char(SUM(l.monthly_rent + l.charges), 'FM999G999D00'), '0') AS value,
       '€' AS unit, 'cash' AS icon, 'azure' AS color
  FROM accounting.lease l
 WHERE l.start_date <= make_date($_year::INT, $_month::INT, 28)
   AND (l.end_date IS NULL OR l.end_date >= make_date($_year::INT, $_month::INT, 1))
   AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT);

-- Rent received
SELECT 'Rent Received' AS title,
       COALESCE(to_char(SUM(rp.amount), 'FM999G999D00'), '0') AS value,
       '€' AS unit, 'circle-check' AS icon, 'green' AS color
  FROM accounting.rent_payment rp
  JOIN accounting.lease l ON l.id = rp.lease_id
 WHERE rp.period_year = $_year::INT AND rp.period_month = $_month::INT
   AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT);

-- Expenses
SELECT 'Expenses' AS title,
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00'), '0') AS value,
       '€' AS unit, 'receipt' AS icon, 'red' AS color
  FROM accounting.invoice i
 WHERE EXTRACT(MONTH FROM i.issue_date) = $_month::INT
   AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND i.status = 'validated'
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

-- Net balance
SELECT 'Net Balance' AS title,
       to_char(
           COALESCE((SELECT SUM(rp.amount)
                       FROM accounting.rent_payment rp
                       JOIN accounting.lease l ON l.id = rp.lease_id
                      WHERE rp.period_year = $_year::INT AND rp.period_month = $_month::INT
                        AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT)), 0)
           - COALESCE((SELECT SUM(i.total_amount)
                         FROM accounting.invoice i
                        WHERE EXTRACT(MONTH FROM i.issue_date) = $_month::INT
                          AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
                          AND i.status = 'validated'
                          AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)), 0),
       'FM999G999D00') AS value,
       '€' AS unit, 'scale' AS icon,
       CASE WHEN COALESCE((SELECT SUM(rp.amount)
                              FROM accounting.rent_payment rp
                              JOIN accounting.lease l ON l.id = rp.lease_id
                             WHERE rp.period_year = $_year::INT AND rp.period_month = $_month::INT
                               AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT)), 0)
                - COALESCE((SELECT SUM(i.total_amount)
                              FROM accounting.invoice i
                             WHERE EXTRACT(MONTH FROM i.issue_date) = $_month::INT
                               AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
                               AND i.status = 'validated'
                               AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)), 0)
                >= 0 THEN 'green' ELSE 'red' END AS color;

-- ── Per-property table ──────────────────────────────────────────────────────

SELECT 'title' AS component,
       'By Property — ' || to_char(make_date($_year::INT, $_month::INT, 1), 'Month YYYY') AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Rent Expected,Rent Received,Expenses,Net,Mortgage,Cash-Flow' AS align_right,
       'No properties.' AS empty_description;

SELECT p.name AS "Property",
       COALESCE(to_char(rent_expected.v, 'FM999G999D00'), '0') || ' €' AS "Rent Expected",
       COALESCE(to_char(rent_received.v, 'FM999G999D00'), '0') || ' €' AS "Rent Received",
       COALESCE(to_char(expenses.v, 'FM999G999D00'), '0') || ' €' AS "Expenses",
       to_char(COALESCE(rent_received.v, 0) - COALESCE(expenses.v, 0), 'FM999G999D00') || ' €' AS "Net",
       COALESCE(to_char(p.mortgage_monthly, 'FM999G999D00'), '0') || ' €' AS "Mortgage",
       to_char(COALESCE(rent_received.v, 0) - COALESCE(expenses.v, 0) - COALESCE(p.mortgage_monthly, 0), 'FM999G999D00') || ' €' AS "Cash-Flow",
       CASE WHEN COALESCE(rent_received.v, 0) - COALESCE(expenses.v, 0) - COALESCE(p.mortgage_monthly, 0) >= 0
            THEN 'green' ELSE 'red' END AS _sqlpage_color
  FROM accounting.property p
  LEFT JOIN LATERAL (
      SELECT SUM(l.monthly_rent + l.charges) AS v
        FROM accounting.lease l
       WHERE l.property_id = p.id
         AND l.start_date <= make_date($_year::INT, $_month::INT, 28)
         AND (l.end_date IS NULL OR l.end_date >= make_date($_year::INT, $_month::INT, 1))
  ) rent_expected ON TRUE
  LEFT JOIN LATERAL (
      SELECT SUM(rp.amount) AS v
        FROM accounting.rent_payment rp
        JOIN accounting.lease l ON l.id = rp.lease_id
       WHERE l.property_id = p.id
         AND rp.period_year = $_year::INT AND rp.period_month = $_month::INT
  ) rent_received ON TRUE
  LEFT JOIN LATERAL (
      SELECT SUM(i.total_amount) AS v
        FROM accounting.invoice i
       WHERE i.property_id = p.id
         AND EXTRACT(MONTH FROM i.issue_date) = $_month::INT
         AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
         AND i.status = 'validated'
  ) expenses ON TRUE
 WHERE ($property IS NULL OR $property = '' OR p.id = $property::INT)
 ORDER BY p.name;
