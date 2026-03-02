-- properties.sql — Gestion des biens immobiliers LMNP

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── En-tete ─────────────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Mes biens immobiliers' AS title,
       'Retrouvez ici l''ensemble de vos biens en location meublee. Chaque bien centralise ses informations, son bail actif, et l''historique de ses factures.' AS description;

-- ── Formulaire d'ajout ───────────────────────────────────────────────────────

SELECT 'form' AS component,
       'POST' AS method,
       'save_property.sql' AS action,
       'Ajouter ce bien' AS validate,
       'plus' AS validate_icon,
       'green' AS validate_color,
       'Ajouter un nouveau bien' AS title;

SELECT 'text' AS type, 'name' AS name, 'Nom du bien' AS label,
       TRUE AS required, 'Ex: Studio Paris 11e' AS placeholder, 4 AS width,
       'Un nom court et parlant pour identifier facilement ce bien.' AS description;

SELECT 'text' AS type, 'address' AS name, 'Adresse' AS label,
       'Adresse complete' AS placeholder, 4 AS width;

SELECT 'text' AS type, 'city' AS name, 'Ville' AS label, 2 AS width;

SELECT 'select' AS type, 'type' AS name, 'Type de bien' AS label, 2 AS width,
       '[{"label":"Appartement","value":"apartment"},{"label":"Maison","value":"house"},{"label":"Studio","value":"studio"},{"label":"Parking","value":"parking"},{"label":"Autre","value":"other"}]' AS options;

SELECT 'number' AS type, 'purchase_price' AS name, 'Prix d''achat (€)' AS label,
       3 AS width, 0.01 AS step,
       'Utile pour calculer le rendement brut et net.' AS description;

SELECT 'date' AS type, 'purchase_date' AS name, 'Date d''achat' AS label, 3 AS width;

SELECT 'number' AS type, 'surface_area' AS name, 'Surface (m²)' AS label,
       2 AS width, 0.01 AS step;

SELECT 'number' AS type, 'mortgage_monthly' AS name, 'Mensualite credit (€)' AS label,
       2 AS width, 0.01 AS step,
       'Deduite du cash-flow dans les analyses.' AS description;

SELECT 'date' AS type, 'mortgage_start_date' AS name, 'Debut du credit' AS label, 2 AS width;

-- ── Liste des biens ──────────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Vos biens' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Cliquez sur un bien pour voir sa fiche complete : detail du bail, historique des factures, et indicateurs de rentabilite.' AS contents,
       TRUE AS italics;

SELECT 'alert' AS component,
       'home-plus' AS icon,
       'azure' AS color,
       'Aucun bien enregistre' AS title,
       'Commencez par ajouter votre premier bien via le formulaire ci-dessus. Vous pourrez ensuite y rattacher des locataires et des factures.' AS description
 WHERE NOT EXISTS (SELECT 1 FROM accounting.property);

SELECT 'card' AS component, 3 AS columns;

SELECT p.name AS title,
       COALESCE(p.address || ', ' || p.city, p.address, p.city, 'Adresse non renseignee') AS description,
       CASE p.type
           WHEN 'apartment' THEN 'building'
           WHEN 'house' THEN 'home'
           WHEN 'studio' THEN 'bed'
           WHEN 'parking' THEN 'parking'
           ELSE 'dots' END AS icon,
       'property.sql?id=' || p.id AS link,
       CASE WHEN t.name IS NOT NULL THEN 'green' ELSE 'azure' END AS color,
       COALESCE('Locataire : ' || t.name, 'Pas de locataire') || ' — ' ||
           (SELECT COUNT(*) || ' facture(s), ' ||
                   COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00') || ' €', '0 €')
              FROM accounting.invoice i WHERE i.property_id = p.id) AS footer_md
  FROM accounting.property p
  LEFT JOIN accounting.lease l
    ON l.property_id = p.id AND l.end_date IS NULL
  LEFT JOIN accounting.tenant t ON t.id = l.tenant_id
 ORDER BY p.name;
