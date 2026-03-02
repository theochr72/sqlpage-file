-- profitability.sql — Analyse de rentabilite annuelle

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── En-tete ─────────────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Rentabilite' AS title,
       'Analysez la performance financiere de vos biens sur une annee complete. Rendement brut, rendement net, cash-flow mensuel et taux d''occupation : tout est calcule automatiquement.' AS description;

-- ── Filtres ─────────────────────────────────────────────────────────────────

SET _year = COALESCE(NULLIF($year, ''), EXTRACT(YEAR FROM CURRENT_DATE)::TEXT);

SELECT 'form' AS component,
       'GET' AS method,
       'profitability.sql' AS action,
       'Filtrer' AS validate,
       'filter' AS validate_icon,
       'azure' AS validate_color;

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
       'Comparez tous vos biens ou concentrez-vous sur un seul.' AS description,
       (SELECT json_agg(json_build_object('label', p.name, 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

-- ── Explications des indicateurs ────────────────────────────────────────────

SELECT 'text' AS component, 'Comment lire ce tableau ?' AS title;
SELECT '**Rendement brut** = loyers annuels / prix d''achat. ' AS contents_md, TRUE AS bold;
SELECT '**Rendement net** = (loyers - depenses - credit annuel) / prix d''achat. ' AS contents_md;
SELECT '**Cash-flow mensuel** = resultat net divise par 12. ' AS contents_md;
SELECT '**Occupation** = proportion de jours avec un bail actif sur l''annee.' AS contents_md;

-- ── Tableau de rentabilite ──────────────────────────────────────────────────

SELECT 'divider' AS component, 'Rentabilite par bien — ' || $_year AS contents, 3 AS size;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Prix d''achat,Surface,Loyers recus,Depenses,Credit annuel,Resultat net,Rdt brut,Rdt net,Cash-flow/mois,Occupation' AS align_right,
       'Aucun bien enregistre. Ajoutez des biens avec un prix d''achat pour voir les calculs de rentabilite.' AS empty_description;

SELECT p.name AS "Bien",
       COALESCE(to_char(p.purchase_price, 'FM999G999') || ' €', '—') AS "Prix d'achat",
       COALESCE(p.surface_area::TEXT || ' m²', '—') AS "Surface",
       COALESCE(to_char(rent.total, 'FM999G999D00') || ' €', '0 €') AS "Loyers recus",
       COALESCE(to_char(exp.total, 'FM999G999D00') || ' €', '0 €') AS "Depenses",
       COALESCE(to_char(p.mortgage_monthly * 12, 'FM999G999D00') || ' €', '0 €') AS "Credit annuel",
       to_char(COALESCE(rent.total, 0) - COALESCE(exp.total, 0) - COALESCE(p.mortgage_monthly * 12, 0), 'FM999G999D00') || ' €' AS "Resultat net",
       CASE WHEN p.purchase_price > 0
            THEN ROUND(COALESCE(rent.total, 0) / p.purchase_price * 100, 1)::TEXT || '%'
            ELSE '—' END AS "Rdt brut",
       CASE WHEN p.purchase_price > 0
            THEN ROUND((COALESCE(rent.total, 0) - COALESCE(exp.total, 0) - COALESCE(p.mortgage_monthly * 12, 0))
                        / p.purchase_price * 100, 1)::TEXT || '%'
            ELSE '—' END AS "Rdt net",
       to_char((COALESCE(rent.total, 0) - COALESCE(exp.total, 0) - COALESCE(p.mortgage_monthly * 12, 0)) / 12, 'FM999G999D00') || ' €' AS "Cash-flow/mois",
       COALESCE(ROUND(occ.days_occupied::NUMERIC / 365 * 100)::TEXT || '%', '0%') AS "Occupation",
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

-- ── Comparaison N vs N-1 ───────────────────────────────────────────────────

SELECT 'divider' AS component, 'Comparaison avec l''annee precedente' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Ce graphique compare les loyers recus et les depenses entre ' || $_year || ' et ' || ($_year::INT - 1)::TEXT || ' pour chaque bien.' AS contents,
       TRUE AS italics;

SELECT 'chart' AS component,
       'Revenus et depenses : ' || $_year || ' vs ' || ($_year::INT - 1)::TEXT AS title,
       'bar' AS type,
       TRUE AS labels,
       TRUE AS toolbar,
       350 AS height;

SELECT p.name AS x,
       COALESCE(rent_n.total, 0)::REAL AS y,
       'Loyers ' || $_year AS series
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
       'Loyers ' || ($_year::INT - 1)::TEXT AS series
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
       'Depenses ' || $_year AS series
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
       'Depenses ' || ($_year::INT - 1)::TEXT AS series
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

-- ── Cash-flow mensuel ───────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Evolution du cash-flow mensuel' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Ce graphique montre mois par mois la difference entre les loyers recus et les depenses. Un cash-flow positif signifie que vos biens sont auto-finances.' AS contents,
       TRUE AS italics;

SELECT 'chart' AS component,
       'Cash-flow mensuel — ' || $_year AS title,
       'area' AS type,
       TRUE AS toolbar,
       0 AS marker,
       350 AS height;

SELECT to_char(make_date($_year::INT, m.n, 1), 'TMMonth') AS x,
       (COALESCE(rent_m.total, 0) - COALESCE(exp_m.total, 0))::REAL AS y,
       'Cash-flow' AS series
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
