-- save_recurring.sql — Insert or update a recurring expense template

UPDATE accounting.recurring_expense
   SET property_id   = $property_id::INT,
       category_code = NULLIF($category_code, ''),
       supplier_name = NULLIF($supplier_name, ''),
       description   = $description,
       amount        = $amount::NUMERIC,
       frequency     = COALESCE(NULLIF($frequency, ''), 'monthly'),
       active        = COALESCE($active::BOOLEAN, TRUE)
 WHERE id = $id::INT
   AND $id IS NOT NULL AND $id != '';

INSERT INTO accounting.recurring_expense (property_id, category_code, supplier_name, description, amount, frequency)
SELECT $property_id::INT,
       NULLIF($category_code, ''),
       NULLIF($supplier_name, ''),
       $description,
       $amount::NUMERIC,
       COALESCE(NULLIF($frequency, ''), 'monthly')
 WHERE $property_id IS NOT NULL AND $property_id != ''
   AND $description IS NOT NULL AND $description != ''
   AND ($id IS NULL OR $id = '');

SELECT 'redirect' AS component, 'recurring.sql' AS link;
