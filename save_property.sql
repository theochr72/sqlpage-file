-- save_property.sql — Ajoute un nouveau bien immobilier

INSERT INTO accounting.property (name, address, city, type)
SELECT $name, NULLIF($address, ''), NULLIF($city, ''), COALESCE(NULLIF($type, ''), 'apartment')
 WHERE $name IS NOT NULL AND $name != '';

SELECT 'redirect' AS component,
       'properties.sql' AS link;
