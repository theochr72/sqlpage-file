-- monthly.sql — Bilan mensuel (loyers vs depenses vs cash-flow)

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── En-tete ─────────────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Bilan mensuel' AS title,
       'Comparez vos loyers recus et vos depenses pour un mois donne. Le tableau detaille montre le cash-flow par bien, credit compris.' AS description;

-- ── Filtres ─────────────────────────────────────────────────────────────────

SET _year  = COALESCE(NULLIF($year, ''), EXTRACT(YEAR FROM CURRENT_DATE)::TEXT);
SET _month = COALESCE(NULLIF($month, ''), EXTRACT(MONTH FROM CURRENT_DATE)::TEXT);

SELECT 'form' AS component,
       'GET' AS method,
       'monthly.sql' AS action,
       'Filtrer' AS validate,
       'filter' AS validate_icon,
       'azure' AS validate_color;

SELECT 'select' AS type, 'month' AS name, 'Mois' AS label,
       $_month AS value, 4 AS width, TRUE AS dropdown,
       '[{"label":"Janvier","value":"1"},{"label":"Fevrier","value":"2"},{"label":"Mars","value":"3"},{"label":"Avril","value":"4"},{"label":"Mai","value":"5"},{"label":"Juin","value":"6"},{"label":"Juillet","value":"7"},{"label":"Aout","value":"8"},{"label":"Septembre","value":"9"},{"label":"Octobre","value":"10"},{"label":"Novembre","value":"11"},{"label":"Decembre","value":"12"}]' AS options;

SELECT 'select' AS type, 'year' AS name, 'Annee' AS label,
       $_year AS value, 4 AS width, TRUE AS dropdown,
       (SELECT json_agg(json_build_object('label', y::TEXT, 'value', y::TEXT) ORDER BY y DESC)
          FROM generate_series(
              EXTRACT(YEAR FROM CURRENT_DATE)::INT - 3,
              EXTRACT(YEAR FROM CURRENT_DATE)::INT + 1
          ) AS y
       )::TEXT AS options;

SELECT 'select' AS type, 'property' AS name, 'Bien' AS label,
       $property AS value, 4 AS width, TRUE AS dropdown, TRUE AS empty_option,
       'Laissez vide pour voir tous les biens.' AS description,
       (SELECT json_agg(json_build_object('label', p.name, 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

-- ── KPIs du mois ────────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 4 AS columns;

SELECT 'Loyers attendus' AS title,
       COALESCE(to_char(SUM(l.monthly_rent + l.charges), 'FM999G999D00'), '0') AS value,
       '€' AS unit, 'cash' AS icon, 'azure' AS color,
       'Somme des loyers + charges des baux actifs ce mois.' AS description
  FROM accounting.lease l
 WHERE l.start_date <= make_date($_year::INT, $_month::INT, 28)
   AND (l.end_date IS NULL OR l.end_date >= make_date($_year::INT, $_month::INT, 1))
   AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT);

SELECT 'Loyers recus' AS title,
       COALESCE(to_char(SUM(rp.amount), 'FM999G999D00'), '0') AS value,
       '€' AS unit, 'circle-check' AS icon, 'green' AS color,
       'Paiements effectivement enregistres.' AS description
  FROM accounting.rent_payment rp
  JOIN accounting.lease l ON l.id = rp.lease_id
 WHERE rp.period_year = $_year::INT AND rp.period_month = $_month::INT
   AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT);

SELECT 'Depenses' AS title,
       COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00'), '0') AS value,
       '€' AS unit, 'receipt' AS icon, 'red' AS color,
       'Factures validees pour ce mois.' AS description
  FROM accounting.invoice i
 WHERE EXTRACT(MONTH FROM i.issue_date) = $_month::INT
   AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
   AND i.status = 'validated'
   AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT);

SELECT 'Solde net' AS title,
       to_char(cf.rent - cf.expenses, 'FM999G999D00') AS value,
       '€' AS unit, 'scale' AS icon,
       'Loyers recus moins depenses (hors credit).' AS description,
       CASE WHEN cf.rent - cf.expenses >= 0 THEN 'green' ELSE 'red' END AS color
  FROM (
      SELECT COALESCE((SELECT SUM(rp.amount)
                         FROM accounting.rent_payment rp
                         JOIN accounting.lease l ON l.id = rp.lease_id
                        WHERE rp.period_year = $_year::INT AND rp.period_month = $_month::INT
                          AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT)), 0) AS rent,
             COALESCE((SELECT SUM(i.total_amount)
                         FROM accounting.invoice i
                        WHERE EXTRACT(MONTH FROM i.issue_date) = $_month::INT
                          AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = $_year::INT
                          AND i.status = 'validated'
                          AND ($property IS NULL OR $property = '' OR i.property_id = $property::INT)), 0) AS expenses
  ) cf;

-- ── Tableau par bien ────────────────────────────────────────────────────────

SELECT 'divider' AS component,
       'Detail par bien — ' || to_char(make_date($_year::INT, $_month::INT, 1), 'TMMonth YYYY') AS contents,
       3 AS size;

SELECT 'text' AS component;
SELECT 'Pour chaque bien : loyers attendus vs recus, depenses du mois, et cash-flow apres deduction de la mensualite de credit. Les lignes vertes indiquent un cash-flow positif.' AS contents,
       TRUE AS italics;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Loyer attendu,Loyer recu,Depenses,Net,Credit,Cash-flow' AS align_right,
       'Aucun bien enregistre.' AS empty_description;

SELECT p.name AS "Bien",
       COALESCE(to_char(rent_expected.v, 'FM999G999D00'), '0') || ' €' AS "Loyer attendu",
       COALESCE(to_char(rent_received.v, 'FM999G999D00'), '0') || ' €' AS "Loyer recu",
       COALESCE(to_char(expenses.v, 'FM999G999D00'), '0') || ' €' AS "Depenses",
       to_char(COALESCE(rent_received.v, 0) - COALESCE(expenses.v, 0), 'FM999G999D00') || ' €' AS "Net",
       COALESCE(to_char(p.mortgage_monthly, 'FM999G999D00'), '0') || ' €' AS "Credit",
       to_char(COALESCE(rent_received.v, 0) - COALESCE(expenses.v, 0) - COALESCE(p.mortgage_monthly, 0), 'FM999G999D00') || ' €' AS "Cash-flow",
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
