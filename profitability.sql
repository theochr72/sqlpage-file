-- profitability.sql — Annual profitability analysis per property

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'title' AS component, 'Profitability' AS contents, 2 AS level;

-- ── Filters ─────────────────────────────────────────────────────────────────

SET _year = COALESCE(NULLIF($year, ''), EXTRACT(YEAR FROM CURRENT_DATE)::TEXT);

SELECT 'form' AS component,
       'GET' AS method,
       'profitability.sql' AS action,
       'Filter' AS validate,
       'filter' AS validate_icon,
       'azure' AS validate_color;

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

-- ── KPIs per property (datagrid) ────────────────────────────────────────────

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Purchase Price,Surface,Rent Received,Expenses,Mortgage (year),Net Result,Gross Yield,Net Yield,Monthly Cash-Flow,Occupancy' AS align_right,
       'No properties.' AS empty_description;

SELECT p.name AS "Property",
       COALESCE(to_char(p.purchase_price, 'FM999G999') || ' €', '—') AS "Purchase Price",
       COALESCE(p.surface_area::TEXT || ' m²', '—') AS "Surface",
       COALESCE(to_char(rent.total, 'FM999G999D00') || ' €', '0 €') AS "Rent Received",
       COALESCE(to_char(exp.total, 'FM999G999D00') || ' €', '0 €') AS "Expenses",
       COALESCE(to_char(p.mortgage_monthly * 12, 'FM999G999D00') || ' €', '0 €') AS "Mortgage (year)",
       to_char(COALESCE(rent.total, 0) - COALESCE(exp.total, 0) - COALESCE(p.mortgage_monthly * 12, 0), 'FM999G999D00') || ' €' AS "Net Result",
       -- Gross yield = rent / purchase_price * 100
       CASE WHEN p.purchase_price > 0
            THEN ROUND(COALESCE(rent.total, 0) / p.purchase_price * 100, 1)::TEXT || '%'
            ELSE '—' END AS "Gross Yield",
       -- Net yield = (rent - expenses - mortgage*12) / purchase_price * 100
       CASE WHEN p.purchase_price > 0
            THEN ROUND((COALESCE(rent.total, 0) - COALESCE(exp.total, 0) - COALESCE(p.mortgage_monthly * 12, 0))
                        / p.purchase_price * 100, 1)::TEXT || '%'
            ELSE '—' END AS "Net Yield",
       -- Monthly cash-flow = (rent - expenses - mortgage*12) / 12
       to_char((COALESCE(rent.total, 0) - COALESCE(exp.total, 0) - COALESCE(p.mortgage_monthly * 12, 0)) / 12, 'FM999G999D00') || ' €' AS "Monthly Cash-Flow",
       -- Occupancy = days with active lease / days in year
       COALESCE(ROUND(occ.days_occupied::NUMERIC / 365 * 100)::TEXT || '%', '0%') AS "Occupancy",
       CASE WHEN COALESCE(rent.total, 0) - COALESCE(exp.total, 0) - COALESCE(p.mortgage_monthly * 12, 0) >= 0
            THEN 'green' ELSE 'red' END AS _sqlpage_color
  FROM accounting.property p
  LEFT JOIN LATERAL (
      SELECT SUM(rp.amount) AS total
        FROM accounting.rent_payment rp
        JOIN accounting.lease l ON l.id = rp.lease_id
       WHERE l.property_id = p.id AND rp.period_year = $_year::INT
  ) rent ON TRUE
  LEFT JOIN LATERAL (
      SELECT SUM(i.total_amount) AS total
        FROM accounting.invoice i
       WHERE i.property_id = p.id
         AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
         AND i.status = 'validated'
  ) exp ON TRUE
  LEFT JOIN LATERAL (
      SELECT SUM(
          LEAST(COALESCE(l.end_date, make_date($_year::INT, 12, 31)), make_date($_year::INT, 12, 31))
          - GREATEST(l.start_date, make_date($_year::INT, 1, 1))
          + 1
      ) AS days_occupied
        FROM accounting.lease l
       WHERE l.property_id = p.id
         AND l.start_date <= make_date($_year::INT, 12, 31)
         AND (l.end_date IS NULL OR l.end_date >= make_date($_year::INT, 1, 1))
  ) occ ON TRUE
 WHERE ($property IS NULL OR $property = '' OR p.id = $property::INT)
 ORDER BY p.name;

-- ── Chart: Revenue comparison N vs N-1 ──────────────────────────────────────

SELECT 'chart' AS component,
       'Revenue Comparison' AS title,
       'bar' AS type,
       TRUE AS labels,
       TRUE AS toolbar,
       350 AS height;

SELECT p.name AS x,
       COALESCE(rent_n.total, 0)::REAL AS y,
       $_year || ' Rent' AS series
  FROM accounting.property p
  LEFT JOIN LATERAL (
      SELECT SUM(rp.amount) AS total
        FROM accounting.rent_payment rp
        JOIN accounting.lease l ON l.id = rp.lease_id
       WHERE l.property_id = p.id AND rp.period_year = $_year::INT
  ) rent_n ON TRUE
 WHERE ($property IS NULL OR $property = '' OR p.id = $property::INT)
 ORDER BY p.name;

SELECT p.name AS x,
       COALESCE(rent_prev.total, 0)::REAL AS y,
       ($_year::INT - 1)::TEXT || ' Rent' AS series
  FROM accounting.property p
  LEFT JOIN LATERAL (
      SELECT SUM(rp.amount) AS total
        FROM accounting.rent_payment rp
        JOIN accounting.lease l ON l.id = rp.lease_id
       WHERE l.property_id = p.id AND rp.period_year = $_year::INT - 1
  ) rent_prev ON TRUE
 WHERE ($property IS NULL OR $property = '' OR p.id = $property::INT)
 ORDER BY p.name;

SELECT p.name AS x,
       COALESCE(exp_n.total, 0)::REAL AS y,
       $_year || ' Expenses' AS series
  FROM accounting.property p
  LEFT JOIN LATERAL (
      SELECT SUM(i.total_amount) AS total
        FROM accounting.invoice i
       WHERE i.property_id = p.id
         AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
         AND i.status = 'validated'
  ) exp_n ON TRUE
 WHERE ($property IS NULL OR $property = '' OR p.id = $property::INT)
 ORDER BY p.name;

SELECT p.name AS x,
       COALESCE(exp_prev.total, 0)::REAL AS y,
       ($_year::INT - 1)::TEXT || ' Expenses' AS series
  FROM accounting.property p
  LEFT JOIN LATERAL (
      SELECT SUM(i.total_amount) AS total
        FROM accounting.invoice i
       WHERE i.property_id = p.id
         AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT - 1
         AND i.status = 'validated'
  ) exp_prev ON TRUE
 WHERE ($property IS NULL OR $property = '' OR p.id = $property::INT)
 ORDER BY p.name;

-- ── Chart: Monthly cash-flow (area) ─────────────────────────────────────────

SELECT 'chart' AS component,
       'Monthly Cash-Flow — ' || $_year AS title,
       'area' AS type,
       TRUE AS toolbar,
       0 AS marker,
       350 AS height;

SELECT to_char(make_date($_year::INT, m.n, 1), 'Mon') AS x,
       (COALESCE(rent_m.total, 0) - COALESCE(exp_m.total, 0))::REAL AS y,
       'Cash-Flow' AS series
  FROM generate_series(1, 12) AS m(n)
  LEFT JOIN LATERAL (
      SELECT SUM(rp.amount) AS total
        FROM accounting.rent_payment rp
        JOIN accounting.lease l ON l.id = rp.lease_id
       WHERE rp.period_year = $_year::INT AND rp.period_month = m.n
         AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT)
  ) rent_m ON TRUE
  LEFT JOIN LATERAL (
      SELECT SUM(i.total_amount) AS total
        FROM accounting.invoice i
       WHERE EXTRACT(MONTH FROM i.issue_date) = m.n
         AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
         AND i.status = 'validated'
         AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)
  ) exp_m ON TRUE
 ORDER BY m.n;
