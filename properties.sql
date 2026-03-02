-- properties.sql — Gestion des biens immobiliers LMNP

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'title' AS component,
       'Properties' AS contents,
       2 AS level;

-- ── Formulaire d'ajout ───────────────────────────────────────────────────────

SELECT 'form' AS component,
       'POST' AS method,
       'save_property.sql' AS action,
       'Add Property' AS validate,
       'plus' AS validate_icon,
       'azure' AS validate_color,
       'New Property' AS title;

SELECT 'text' AS type, 'name' AS name, 'Name' AS label,
       TRUE AS required, 'Ex: Studio Paris 11' AS placeholder, 4 AS width;

SELECT 'text' AS type, 'address' AS name, 'Address' AS label,
       'Full address' AS placeholder, 4 AS width;

SELECT 'text' AS type, 'city' AS name, 'City' AS label, 2 AS width;

SELECT 'select' AS type, 'type' AS name, 'Type' AS label, 2 AS width,
       '[{"label":"Apartment","value":"apartment"},{"label":"House","value":"house"},{"label":"Studio","value":"studio"},{"label":"Parking","value":"parking"},{"label":"Other","value":"other"}]' AS options;

SELECT 'number' AS type, 'purchase_price' AS name, 'Purchase Price (€)' AS label,
       3 AS width, 0.01 AS step, 'price-tag' AS prefix_icon;

SELECT 'date' AS type, 'purchase_date' AS name, 'Purchase Date' AS label, 3 AS width;

SELECT 'number' AS type, 'surface_area' AS name, 'Surface (m²)' AS label,
       2 AS width, 0.01 AS step;

SELECT 'number' AS type, 'mortgage_monthly' AS name, 'Monthly Mortgage (€)' AS label,
       2 AS width, 0.01 AS step;

SELECT 'date' AS type, 'mortgage_start_date' AS name, 'Mortgage Start' AS label, 2 AS width;

-- ── Liste des biens ──────────────────────────────────────────────────────────

SELECT 'card' AS component, 3 AS columns;

SELECT p.name AS title,
       COALESCE(p.address, '') AS description,
       COALESCE(p.city, '') AS footer,
       CASE p.type
           WHEN 'apartment' THEN 'building'
           WHEN 'house' THEN 'home'
           WHEN 'studio' THEN 'bed'
           WHEN 'parking' THEN 'parking'
           ELSE 'dots' END AS icon,
       'property.sql?id=' || p.id AS link,
       COALESCE(t.name, 'No tenant') || ' — ' ||
           (SELECT COUNT(*) || ' invoices — ' ||
                   COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00') || ' EUR', '0 EUR')
              FROM accounting.invoice i WHERE i.property_id = p.id) AS footer_md
  FROM accounting.property p
  LEFT JOIN accounting.lease l
    ON l.property_id = p.id AND l.end_date IS NULL
  LEFT JOIN accounting.tenant t ON t.id = l.tenant_id
 ORDER BY p.name;
