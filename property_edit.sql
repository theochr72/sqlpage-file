-- property_edit.sql — Modifier un bien

SELECT 'redirect' AS component, 'properties.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'breadcrumb' AS component;
SELECT 'Tableau de bord' AS title, '/' AS link;
SELECT 'Mes biens' AS title, '/properties.sql' AS link;
SELECT p.name AS title, 'property.sql?id=' || p.id AS link
  FROM accounting.property p WHERE p.id = $id::INT;
SELECT 'Modifier' AS title, TRUE AS active;

SELECT 'text' AS component;
SELECT 'Modifiez les informations de votre bien. Les champs de financement sont utilises pour calculer automatiquement le cash-flow et la rentabilite.' AS contents,
       TRUE AS italics;

SELECT 'form' AS component,
       'POST' AS method,
       'save_property.sql?id=' || $id AS action,
       'Enregistrer' AS validate,
       'device-floppy' AS validate_icon,
       'green' AS validate_color,
       'Modifier le bien' AS title;

SELECT 'text' AS type, 'name' AS name, 'Nom du bien' AS label,
       p.name AS value, TRUE AS required, 4 AS width
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'text' AS type, 'address' AS name, 'Adresse' AS label,
       p.address AS value, 4 AS width
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'text' AS type, 'city' AS name, 'Ville' AS label,
       p.city AS value, 2 AS width
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'select' AS type, 'type' AS name, 'Type de bien' AS label, 2 AS width,
       p.type AS value,
       '[{"label":"Appartement","value":"apartment"},{"label":"Maison","value":"house"},{"label":"Studio","value":"studio"},{"label":"Parking","value":"parking"},{"label":"Autre","value":"other"}]' AS options
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'number' AS type, 'purchase_price' AS name, 'Prix d''achat (€)' AS label,
       p.purchase_price::TEXT AS value, 3 AS width, 0.01 AS step,
       'Base de calcul du rendement brut et net.' AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'date' AS type, 'purchase_date' AS name, 'Date d''achat' AS label,
       p.purchase_date::TEXT AS value, 3 AS width
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'number' AS type, 'surface_area' AS name, 'Surface (m²)' AS label,
       p.surface_area::TEXT AS value, 2 AS width, 0.01 AS step
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'number' AS type, 'mortgage_monthly' AS name, 'Mensualite credit (€)' AS label,
       p.mortgage_monthly::TEXT AS value, 2 AS width, 0.01 AS step,
       'Montant preleve chaque mois, deduit du cash-flow.' AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'date' AS type, 'mortgage_start_date' AS name, 'Debut du credit' AS label,
       p.mortgage_start_date::TEXT AS value, 2 AS width
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'date' AS type, 'mortgage_end_date' AS name, 'Fin du credit' AS label,
       p.mortgage_end_date::TEXT AS value, 2 AS width
  FROM accounting.property p WHERE p.id = $id::INT;
