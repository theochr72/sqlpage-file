-- save_supplier_mapping.sql — Insert or update a supplier mapping

-- Guard: need a non-empty pattern
SELECT 'redirect' AS component, 'supplier_mappings.sql' AS link
 WHERE $supplier_pattern IS NULL OR TRIM($supplier_pattern) = '';

INSERT INTO accounting.supplier_mapping (supplier_pattern, category_code, property_id)
VALUES (
    LOWER(TRIM($supplier_pattern)),
    NULLIF($category_code, ''),
    NULLIF($property_id, '')::INT
)
ON CONFLICT (supplier_pattern) DO UPDATE SET
    category_code = EXCLUDED.category_code,
    property_id   = EXCLUDED.property_id;

SELECT 'redirect' AS component,
       'supplier_mappings.sql?saved=1' AS link;
