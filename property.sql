-- property.sql — Fiche detaillee d'un bien

SELECT 'redirect' AS component, 'properties.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── Navigation ──────────────────────────────────────────────────────────────

SELECT 'breadcrumb' AS component;
SELECT 'Tableau de bord' AS title, '/' AS link;
SELECT 'Mes biens' AS title, '/properties.sql' AS link;
SELECT p.name AS title, TRUE AS active
  FROM accounting.property p WHERE p.id = $id::INT;

-- ── Infos generales ─────────────────────────────────────────────────────────

SELECT 'datagrid' AS component,
       p.name AS title,
       'Fiche complete du bien : localisation, acquisition, financement.' AS description,
       CASE p.type
           WHEN 'apartment' THEN 'building'
           WHEN 'house' THEN 'home'
           WHEN 'studio' THEN 'bed'
           WHEN 'parking' THEN 'parking'
           ELSE 'dots' END AS icon
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Adresse' AS title, COALESCE(p.address, 'Non renseignee') AS description, 'map-pin' AS icon
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Ville' AS title, COALESCE(p.city, 'Non renseignee') AS description, 'building-community' AS icon
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Type' AS title, COALESCE(INITCAP(p.type), 'Non renseigne') AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Surface' AS title, COALESCE(p.surface_area::TEXT || ' m²', 'Non renseignee') AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Prix d''achat' AS title, COALESCE(to_char(p.purchase_price, 'FM999G999D00') || ' €', 'Non renseigne') AS description, 'currency-euro' AS icon
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Date d''achat' AS title, COALESCE(p.purchase_date::TEXT, 'Non renseignee') AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Mensualite credit' AS title, COALESCE(to_char(p.mortgage_monthly, 'FM999G999D00') || ' €/mois', 'Pas de credit') AS description, 'credit-card' AS icon
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Periode du credit' AS title,
       COALESCE(p.mortgage_start_date::TEXT, '?') || ' → ' || COALESCE(p.mortgage_end_date::TEXT, '?') AS description
  FROM accounting.property p WHERE p.id = $id::INT
   AND (p.mortgage_start_date IS NOT NULL OR p.mortgage_end_date IS NOT NULL);

-- ── Actions ─────────────────────────────────────────────────────────────────

SELECT 'button' AS component, 'start' AS justify, 'sm' AS size;

SELECT 'Modifier' AS title, 'pencil' AS icon, 'azure' AS color,
       'property_edit.sql?id=' || $id AS link;

SELECT 'Ajouter un bail' AS title, 'plus' AS icon, 'green' AS color,
       'leases.sql?property_id=' || $id AS link;

SELECT 'Voir la rentabilite' AS title, 'chart-line' AS icon, 'cyan' AS outline,
       'profitability.sql?property=' || $id AS link;

-- ── Bail en cours ───────────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Bail en cours' AS contents, 3 AS size;

SELECT 'alert' AS component,
       'Aucun bail actif' AS title,
       'Ce bien n''a pas de locataire actuellement. Ajoutez un bail pour commencer a suivre les loyers.' AS description,
       'home-off' AS icon,
       'azure' AS color,
       'leases.sql?property_id=' || $id AS link,
       'Creer un bail' AS link_text
 WHERE NOT EXISTS (
     SELECT 1 FROM accounting.lease WHERE property_id = $id::INT AND end_date IS NULL
 );

SELECT 'datagrid' AS component,
       'Informations du bail actif' AS description
 WHERE EXISTS (SELECT 1 FROM accounting.lease WHERE property_id = $id::INT AND end_date IS NULL);

SELECT 'Locataire' AS title, t.name AS description,
       'tenant.sql?id=' || t.id AS link, 'user' AS icon
  FROM accounting.lease l
  JOIN accounting.tenant t ON t.id = l.tenant_id
 WHERE l.property_id = $id::INT AND l.end_date IS NULL
 LIMIT 1;

SELECT 'Loyer mensuel' AS title,
       to_char(l.monthly_rent, 'FM999G999D00') || ' €' AS description, 'cash' AS icon
  FROM accounting.lease l
 WHERE l.property_id = $id::INT AND l.end_date IS NULL
 LIMIT 1;

SELECT 'Charges' AS title,
       to_char(l.charges, 'FM999G999D00') || ' €' AS description
  FROM accounting.lease l
 WHERE l.property_id = $id::INT AND l.end_date IS NULL AND l.charges > 0
 LIMIT 1;

SELECT 'Debut du bail' AS title, l.start_date::TEXT AS description, 'calendar' AS icon
  FROM accounting.lease l
 WHERE l.property_id = $id::INT AND l.end_date IS NULL
 LIMIT 1;

SELECT 'Depot de garantie' AS title,
       to_char(l.deposit, 'FM999G999D00') || ' €' AS description
  FROM accounting.lease l
 WHERE l.property_id = $id::INT AND l.end_date IS NULL AND l.deposit IS NOT NULL
 LIMIT 1;

-- ── Historique des baux ─────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Historique des baux' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Tous les baux passes et en cours pour ce bien. Les baux actifs sont surlignees en vert.' AS contents,
       TRUE AS italics;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Aucun bail enregistre pour ce bien.' AS empty_description;

SELECT t.name AS "Locataire",
       l.start_date::TEXT AS "Debut",
       COALESCE(l.end_date::TEXT, 'En cours') AS "Fin",
       to_char(l.monthly_rent, 'FM999G999D00') || ' €' AS "Loyer",
       to_char(l.charges, 'FM999G999D00') || ' €' AS "Charges",
       CASE WHEN l.end_date IS NULL THEN 'green' ELSE NULL END AS _sqlpage_color,
       'lease.sql?id=' || l.id AS _sqlpage_id
  FROM accounting.lease l
  JOIN accounting.tenant t ON t.id = l.tenant_id
 WHERE l.property_id = $id::INT
 ORDER BY l.start_date DESC;

-- ── Factures liees ──────────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Factures associees' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Toutes les depenses rattachees a ce bien : travaux, assurance, charges, etc.' AS contents,
       TRUE AS italics;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Montant' AS align_right,
       'Aucune facture rattachee a ce bien. Assignez des factures depuis la page Factures.' AS empty_description;

SELECT i.invoice_number AS "N° Facture",
       i.supplier_name AS "Fournisseur",
       i.issue_date::TEXT AS "Date",
       COALESCE(to_char(i.total_amount, 'FM999G999D00') || ' €', '') AS "Montant",
       COALESCE(c.label, 'Non categorisee') AS "Categorie",
       CASE WHEN i.status = 'validated' THEN 'green'
            WHEN i.status = 'rejected' THEN 'red'
            ELSE NULL END AS _sqlpage_color,
       'invoice.sql?id=' || i.id AS _sqlpage_id
  FROM accounting.invoice i
  LEFT JOIN accounting.expense_category c ON c.code = i.category_code
 WHERE i.property_id = $id::INT
 ORDER BY i.issue_date DESC;
