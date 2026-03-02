-- property_edit.sql — Edit a property

SELECT 'redirect' AS component, 'properties.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'breadcrumb' AS component;
SELECT 'Dashboard' AS title, '/' AS link;
SELECT 'Properties' AS title, '/properties.sql' AS link;
SELECT p.name AS title, 'property.sql?id=' || p.id AS link
  FROM accounting.property p WHERE p.id = $id::INT;
SELECT 'Edit' AS title, TRUE AS active;

SELECT 'form' AS component,
       'POST' AS method,
       'save_property.sql?id=' || $id AS action,
       'Save' AS validate,
       'device-floppy' AS validate_icon,
       'green' AS validate_color,
       'Edit Property' AS title;

SELECT 'text' AS type, 'name' AS name, 'Name' AS label,
       p.name AS value, TRUE AS required, 4 AS width
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'text' AS type, 'address' AS name, 'Address' AS label,
       p.address AS value, 4 AS width
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'text' AS type, 'city' AS name, 'City' AS label,
       p.city AS value, 2 AS width
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'select' AS type, 'type' AS name, 'Type' AS label, 2 AS width,
       p.type AS value,
       '[{"label":"Apartment","value":"apartment"},{"label":"House","value":"house"},{"label":"Studio","value":"studio"},{"label":"Parking","value":"parking"},{"label":"Other","value":"other"}]' AS options
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'number' AS type, 'purchase_price' AS name, 'Purchase Price (€)' AS label,
       p.purchase_price::TEXT AS value, 3 AS width, 0.01 AS step
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'date' AS type, 'purchase_date' AS name, 'Purchase Date' AS label,
       p.purchase_date::TEXT AS value, 3 AS width
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'number' AS type, 'surface_area' AS name, 'Surface (m²)' AS label,
       p.surface_area::TEXT AS value, 2 AS width, 0.01 AS step
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'number' AS type, 'mortgage_monthly' AS name, 'Monthly Mortgage (€)' AS label,
       p.mortgage_monthly::TEXT AS value, 2 AS width, 0.01 AS step
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'date' AS type, 'mortgage_start_date' AS name, 'Mortgage Start' AS label,
       p.mortgage_start_date::TEXT AS value, 2 AS width
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'date' AS type, 'mortgage_end_date' AS name, 'Mortgage End' AS label,
       p.mortgage_end_date::TEXT AS value, 2 AS width
  FROM accounting.property p WHERE p.id = $id::INT;
