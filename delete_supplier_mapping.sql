-- delete_supplier_mapping.sql — Delete a supplier mapping

DELETE FROM accounting.supplier_mapping
 WHERE id = $id::INT
   AND $id IS NOT NULL AND $id != '';

SELECT 'redirect' AS component,
       'supplier_mappings.sql?deleted=1' AS link;
