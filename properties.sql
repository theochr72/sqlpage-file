-- properties.sql — Gestion des biens immobiliers LMNP

SELECT 'shell' AS component,
       'InvoiceAI' AS title,
       'file-invoice' AS icon,
       TRUE AS sidebar,
       'Dashboard' AS menu_item, '/' AS link,
       'Invoices' AS menu_item, '/invoices.sql' AS link,
       'Fiscal' AS menu_item, '/fiscal.sql' AS link,
       'Properties' AS menu_item, '/properties.sql' AS link,
       'Upload' AS menu_item, '/upload.sql' AS link,
       'dark' AS theme,
       'Inter' AS font;

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
       'invoices.sql?property=' || p.id AS link,
       (SELECT COUNT(*) || ' invoices — ' ||
               COALESCE(to_char(SUM(i.total_amount), 'FM999G999D00') || ' EUR', '0 EUR')
          FROM accounting.invoice i WHERE i.property_id = p.id) AS footer_md
  FROM accounting.property p
 ORDER BY p.name;
