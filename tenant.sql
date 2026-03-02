-- tenant.sql — Fiche locataire

SELECT 'redirect' AS component, 'tenants.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'breadcrumb' AS component;
SELECT 'Tableau de bord' AS title, '/' AS link;
SELECT 'Locataires' AS title, '/tenants.sql' AS link;
SELECT t.name AS title, TRUE AS active
  FROM accounting.tenant t WHERE t.id = $id::INT;

-- ── Coordonnees ─────────────────────────────────────────────────────────────

SELECT 'datagrid' AS component,
       t.name AS title,
       'Coordonnees et informations du locataire.' AS description,
       'user' AS icon
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'Email' AS title, COALESCE(t.email, 'Non renseigne') AS description, 'mail' AS icon
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'Telephone' AS title, COALESCE(t.phone, 'Non renseigne') AS description, 'phone' AS icon
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'Notes' AS title, COALESCE(t.notes, 'Aucune note') AS description
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'Enregistre le' AS title, to_char(t.created_at, 'DD/MM/YYYY') AS description, 'calendar' AS icon
  FROM accounting.tenant t WHERE t.id = $id::INT;

-- ── Modifier les infos ──────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Modifier les informations' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Corrigez ou completez les coordonnees du locataire si necessaire.' AS contents,
       TRUE AS italics;

SELECT 'form' AS component,
       'POST' AS method,
       'save_tenant.sql?id=' || $id AS action,
       'Enregistrer' AS validate,
       'device-floppy' AS validate_icon,
       'green' AS validate_color;

SELECT 'text' AS type, 'name' AS name, 'Nom complet' AS label,
       t.name AS value, TRUE AS required, 4 AS width
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'email' AS type, 'email' AS name, 'Email' AS label,
       t.email AS value, 4 AS width
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'tel' AS type, 'phone' AS name, 'Telephone' AS label,
       t.phone AS value, 4 AS width
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'textarea' AS type, 'notes' AS name, 'Notes' AS label,
       t.notes AS value, 12 AS width, 2 AS rows
  FROM accounting.tenant t WHERE t.id = $id::INT;

-- ── Historique des baux ─────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Historique des baux' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Tous les baux passes et presents de ce locataire. Les baux en cours apparaissent en vert.' AS contents,
       TRUE AS italics;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Ce locataire n''a pas encore de bail. Creez-en un depuis la page Baux.' AS empty_description;

SELECT p.name AS "Bien",
       l.start_date::TEXT AS "Debut",
       COALESCE(l.end_date::TEXT, 'En cours') AS "Fin",
       to_char(l.monthly_rent, 'FM999G999D00') || ' €' AS "Loyer",
       to_char(l.charges, 'FM999G999D00') || ' €' AS "Charges",
       CASE WHEN l.end_date IS NULL THEN 'green' ELSE NULL END AS _sqlpage_color,
       'lease.sql?id=' || l.id AS _sqlpage_id
  FROM accounting.lease l
  JOIN accounting.property p ON p.id = l.property_id
 WHERE l.tenant_id = $id::INT
 ORDER BY l.start_date DESC;
