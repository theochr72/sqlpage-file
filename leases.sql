-- leases.sql — Gestion des baux

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── En-tete ─────────────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Baux de location' AS title,
       'Un bail lie un locataire a un bien pour une periode donnee. Suivez ici les baux actifs et termines, et creez-en de nouveaux.' AS description;

-- ── Error feedback ──────────────────────────────────────────────────────────

SELECT 'alert' AS component,
       'alert-triangle' AS icon,
       'red' AS color,
       'Impossible de creer le bail' AS title,
       'Un bail actif (sans date de fin) existe deja pour ce bien. Terminez-le d''abord en ajoutant une date de fin.' AS description,
       TRUE AS dismissible
 WHERE $error = 'overlap';

-- ── Onglets ─────────────────────────────────────────────────────────────────

SELECT 'tab' AS component, TRUE AS center;

SELECT 'En cours' AS title,
       'leases.sql?tab=active' || CASE WHEN $property_id IS NOT NULL AND $property_id != '' THEN '&property_id=' || $property_id ELSE '' END AS link,
       (COALESCE($tab, 'active') = 'active') AS active,
       'circle-check' AS icon, 'green' AS color,
       'Baux sans date de fin' AS description;

SELECT 'Termines' AS title,
       'leases.sql?tab=ended' || CASE WHEN $property_id IS NOT NULL AND $property_id != '' THEN '&property_id=' || $property_id ELSE '' END AS link,
       ($tab = 'ended') AS active,
       'circle-x' AS icon,
       'Baux clos' AS description;

SELECT 'Tous' AS title,
       'leases.sql?tab=all' || CASE WHEN $property_id IS NOT NULL AND $property_id != '' THEN '&property_id=' || $property_id ELSE '' END AS link,
       ($tab = 'all') AS active,
       'list' AS icon;

-- ── Tableau des baux ────────────────────────────────────────────────────────

SELECT 'text' AS component;
SELECT 'Cliquez sur une ligne pour voir le detail du bail, les paiements recus et les actions disponibles.' AS contents,
       TRUE AS italics;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows, TRUE AS search,
       'Loyer,Charges,Depot' AS align_right,
       'Aucun bail trouve. Creez votre premier bail via le formulaire ci-dessous.' AS empty_description;

SELECT t.name AS "Locataire",
       p.name AS "Bien",
       l.start_date::TEXT AS "Debut",
       COALESCE(l.end_date::TEXT, '—') AS "Fin",
       to_char(l.monthly_rent, 'FM999G999D00') || ' €' AS "Loyer",
       to_char(l.charges, 'FM999G999D00') || ' €' AS "Charges",
       COALESCE(to_char(l.deposit, 'FM999G999D00') || ' €', '—') AS "Depot",
       CASE WHEN l.end_date IS NULL THEN 'En cours' ELSE 'Termine' END AS "Statut",
       CASE WHEN l.end_date IS NULL THEN 'green' ELSE NULL END AS _sqlpage_color,
       'lease.sql?id=' || l.id AS _sqlpage_id
  FROM accounting.lease l
  JOIN accounting.tenant t ON t.id = l.tenant_id
  JOIN accounting.property p ON p.id = l.property_id
 WHERE (COALESCE($tab, 'active') = 'all'
        OR (COALESCE($tab, 'active') = 'active' AND l.end_date IS NULL)
        OR ($tab = 'ended' AND l.end_date IS NOT NULL))
   AND ($property_id IS NULL OR $property_id = '' OR l.property_id = $property_id::INT)
 ORDER BY l.start_date DESC;

-- ── Nouveau bail ────────────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Creer un nouveau bail' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Remplissez les informations ci-dessous pour creer un bail. Le locataire et le bien doivent avoir ete crees au prealable. Un seul bail actif (sans date de fin) est autorise par bien.' AS contents,
       TRUE AS italics;

SELECT 'form' AS component,
       'POST' AS method,
       'save_lease.sql' AS action,
       'Creer le bail' AS validate,
       'plus' AS validate_icon,
       'green' AS validate_color;

SELECT 'select' AS type, 'tenant_id' AS name, 'Locataire' AS label,
       TRUE AS required, 4 AS width, TRUE AS dropdown, TRUE AS searchable,
       'Selectionnez le locataire concerne.' AS description,
       (SELECT json_agg(json_build_object('label', t.name, 'value', t.id) ORDER BY t.name)
          FROM accounting.tenant t)::TEXT AS options;

SELECT 'select' AS type, 'property_id' AS name, 'Bien' AS label,
       TRUE AS required, 4 AS width, TRUE AS dropdown, TRUE AS searchable,
       $property_id AS value,
       'Le logement concerne par le bail.' AS description,
       (SELECT json_agg(json_build_object('label', p.name || COALESCE(' — ' || p.city, ''), 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

SELECT 'date' AS type, 'start_date' AS name, 'Date de debut' AS label,
       TRUE AS required, 4 AS width,
       'Date d''entree dans les lieux.' AS description;

SELECT 'date' AS type, 'end_date' AS name, 'Date de fin' AS label,
       4 AS width,
       'Laissez vide pour un bail en cours (duree indeterminee).' AS description;

SELECT 'number' AS type, 'monthly_rent' AS name, 'Loyer mensuel (€)' AS label,
       TRUE AS required, 3 AS width, 0.01 AS step,
       'Hors charges.' AS description;

SELECT 'number' AS type, 'charges' AS name, 'Charges (€)' AS label,
       3 AS width, 0.01 AS step, '0' AS placeholder,
       'Provisions pour charges mensuelles.' AS description;

SELECT 'number' AS type, 'deposit' AS name, 'Depot de garantie (€)' AS label,
       3 AS width, 0.01 AS step,
       'Generalement 1 a 2 mois de loyer HC.' AS description;

SELECT 'date' AS type, 'revision_date' AS name, 'Date de revision' AS label, 3 AS width,
       'Date anniversaire de revision du loyer.' AS description;

SELECT 'textarea' AS type, 'notes' AS name, 'Notes' AS label, 12 AS width, 2 AS rows,
       'Conditions particulieres, clauses specifiques, etc.' AS description;
