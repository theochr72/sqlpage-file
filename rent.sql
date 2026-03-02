-- rent.sql — Suivi des loyers (grille 12 mois x biens)

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── En-tete ─────────────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Suivi des loyers' AS title,
       'Visualisez l''etat des paiements mois par mois pour chaque bien. Les lignes en rouge signalent des loyers en retard : cliquez dessus pour enregistrer le paiement.' AS description;

-- ── Filtres ─────────────────────────────────────────────────────────────────

SET _year = COALESCE(NULLIF($year, ''), EXTRACT(YEAR FROM CURRENT_DATE)::TEXT);

SELECT 'form' AS component,
       'GET' AS method,
       'rent.sql' AS action,
       'Filtrer' AS validate,
       'filter' AS validate_icon,
       'azure' AS validate_color;

SELECT 'select' AS type, 'year' AS name, 'Annee' AS label,
       $_year AS value, 4 AS width, TRUE AS dropdown,
       (SELECT json_agg(json_build_object('label', y::TEXT, 'value', y::TEXT) ORDER BY y DESC)
          FROM generate_series(
              LEAST(EXTRACT(YEAR FROM CURRENT_DATE)::INT - 2,
                    COALESCE((SELECT MIN(EXTRACT(YEAR FROM start_date))::INT FROM accounting.lease), EXTRACT(YEAR FROM CURRENT_DATE)::INT)),
              EXTRACT(YEAR FROM CURRENT_DATE)::INT + 1
          ) AS y
       )::TEXT AS options;

SELECT 'select' AS type, 'property' AS name, 'Bien' AS label,
       $property AS value, 4 AS width, TRUE AS dropdown, TRUE AS empty_option,
       'Filtrer sur un bien specifique, ou laissez vide pour tout voir.' AS description,
       (SELECT json_agg(json_build_object('label', p.name, 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

-- ── KPIs ────────────────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 4 AS columns;

-- Total attendu depuis janvier
SELECT 'Attendu (cumul)' AS title,
       COALESCE(to_char(SUM(l.monthly_rent + l.charges), 'FM999G999D00'), '0') AS value,
       '€' AS unit, 'cash' AS icon, 'azure' AS color,
       'Total des loyers+charges dus depuis janvier.' AS description
  FROM accounting.lease l
  CROSS JOIN generate_series(1, LEAST(
      CASE WHEN $_year::INT = EXTRACT(YEAR FROM CURRENT_DATE)::INT
           THEN EXTRACT(MONTH FROM CURRENT_DATE)::INT ELSE 12 END,
      12)) AS m(n)
 WHERE l.start_date <= make_date($_year::INT, m.n, 28)
   AND (l.end_date IS NULL OR l.end_date >= make_date($_year::INT, m.n, 1))
   AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT);

-- Total recu
SELECT 'Recu (cumul)' AS title,
       COALESCE(to_char(SUM(rp.amount), 'FM999G999D00'), '0') AS value,
       '€' AS unit, 'circle-check' AS icon, 'green' AS color,
       'Paiements effectivement enregistres.' AS description
  FROM accounting.rent_payment rp
  JOIN accounting.lease l ON l.id = rp.lease_id
 WHERE rp.period_year = $_year::INT
   AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT);

-- Impayes
SELECT 'Impayes' AS title,
       COALESCE(to_char(
           (SELECT COALESCE(SUM(l2.monthly_rent + l2.charges), 0)
              FROM accounting.lease l2
              CROSS JOIN generate_series(1, LEAST(
                  CASE WHEN $_year::INT = EXTRACT(YEAR FROM CURRENT_DATE)::INT
                       THEN EXTRACT(MONTH FROM CURRENT_DATE)::INT ELSE 12 END, 12)) AS m2(n)
             WHERE l2.start_date <= make_date($_year::INT, m2.n, 28)
               AND (l2.end_date IS NULL OR l2.end_date >= make_date($_year::INT, m2.n, 1))
               AND ($property IS NULL OR $property = '' OR l2.property_id = $property::INT))
           - COALESCE(SUM(rp.amount), 0),
       'FM999G999D00'), '0') AS value,
       '€' AS unit, 'alert-triangle' AS icon,
       'Difference entre attendu et recu.' AS description,
       CASE WHEN COALESCE(
           (SELECT COALESCE(SUM(l2.monthly_rent + l2.charges), 0)
              FROM accounting.lease l2
              CROSS JOIN generate_series(1, LEAST(
                  CASE WHEN $_year::INT = EXTRACT(YEAR FROM CURRENT_DATE)::INT
                       THEN EXTRACT(MONTH FROM CURRENT_DATE)::INT ELSE 12 END, 12)) AS m2(n)
             WHERE l2.start_date <= make_date($_year::INT, m2.n, 28)
               AND (l2.end_date IS NULL OR l2.end_date >= make_date($_year::INT, m2.n, 1))
               AND ($property IS NULL OR $property = '' OR l2.property_id = $property::INT))
           - COALESCE(SUM(rp.amount), 0), 0) > 0 THEN 'red' ELSE 'green' END AS color
  FROM accounting.rent_payment rp
  JOIN accounting.lease l ON l.id = rp.lease_id
 WHERE rp.period_year = $_year::INT
   AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT);

-- Taux d'occupation
SELECT 'Occupation' AS title,
       COALESCE(ROUND(
           COUNT(DISTINCT l.property_id)::NUMERIC /
           NULLIF((SELECT COUNT(*) FROM accounting.property), 0) * 100
       )::TEXT || '%', '—') AS value,
       'home-check' AS icon, 'cyan' AS color,
       'Proportion de biens avec bail actif.' AS description
  FROM accounting.lease l
 WHERE l.start_date <= CURRENT_DATE
   AND (l.end_date IS NULL OR l.end_date >= CURRENT_DATE)
   AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT);

-- ── Grille mensuelle ────────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Detail mois par mois — ' || $_year AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Chaque ligne represente un mois de bail pour un bien donne. **Vert** = paye, **Rouge** = en retard (cliquez pour enregistrer), **Blanc** = futur.' AS contents_md;

SELECT 'table' AS component,
       TRUE AS hover, TRUE AS striped_rows, TRUE AS striped_columns,
       'Attendu,Recu,Statut' AS align_center,
       'Aucun bail actif pour cette periode. Creez un bail depuis la page Baux.' AS empty_description;

SELECT p.name AS "Bien",
       t.name AS "Locataire",
       to_char(make_date($_year::INT, m.n, 1), 'TMMonth') AS "Mois",
       to_char(l.monthly_rent + l.charges, 'FM999G999D00') || ' €' AS "Attendu",
       COALESCE(to_char(rp.amount, 'FM999G999D00') || ' €', '—') AS "Recu",
       CASE
           WHEN rp.id IS NOT NULL THEN 'Paye'
           WHEN make_date($_year::INT, m.n, 1) > CURRENT_DATE THEN 'A venir'
           ELSE 'En retard'
       END AS "Statut",
       CASE
           WHEN rp.id IS NOT NULL THEN 'green'
           WHEN make_date($_year::INT, m.n, 1) > CURRENT_DATE THEN NULL
           ELSE 'red'
       END AS _sqlpage_color,
       CASE
           WHEN rp.id IS NULL AND make_date($_year::INT, m.n, 1) <= CURRENT_DATE
           THEN 'rent_form.sql?lease_id=' || l.id || '&month=' || m.n || '&year=' || $_year
       END AS _sqlpage_id
  FROM accounting.lease l
  JOIN accounting.property p ON p.id = l.property_id
  JOIN accounting.tenant t ON t.id = l.tenant_id
  CROSS JOIN generate_series(1, 12) AS m(n)
  LEFT JOIN accounting.rent_payment rp
    ON rp.lease_id = l.id AND rp.period_year = $_year::INT AND rp.period_month = m.n
 WHERE l.start_date <= make_date($_year::INT, m.n, 28)
   AND (l.end_date IS NULL OR l.end_date >= make_date($_year::INT, m.n, 1))
   AND ($property IS NULL OR $property = '' OR l.property_id = $property::INT)
 ORDER BY p.name, m.n;
