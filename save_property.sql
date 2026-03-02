-- save_property.sql — Insert or update a property

-- UPDATE if $id is provided
UPDATE accounting.property
   SET name               = $name,
       address            = NULLIF($address, ''),
       city               = NULLIF($city, ''),
       type               = COALESCE(NULLIF($type, ''), 'apartment'),
       purchase_price     = NULLIF($purchase_price, '')::NUMERIC,
       purchase_date      = NULLIF($purchase_date, '')::DATE,
       mortgage_monthly   = NULLIF($mortgage_monthly, '')::NUMERIC,
       mortgage_start_date = NULLIF($mortgage_start_date, '')::DATE,
       mortgage_end_date  = NULLIF($mortgage_end_date, '')::DATE,
       surface_area       = NULLIF($surface_area, '')::NUMERIC
 WHERE id = $id::INT
   AND $id IS NOT NULL AND $id != '';

-- INSERT if no $id
INSERT INTO accounting.property (name, address, city, type, purchase_price, purchase_date,
                                  mortgage_monthly, mortgage_start_date, mortgage_end_date, surface_area)
SELECT $name,
       NULLIF($address, ''),
       NULLIF($city, ''),
       COALESCE(NULLIF($type, ''), 'apartment'),
       NULLIF($purchase_price, '')::NUMERIC,
       NULLIF($purchase_date, '')::DATE,
       NULLIF($mortgage_monthly, '')::NUMERIC,
       NULLIF($mortgage_start_date, '')::DATE,
       NULLIF($mortgage_end_date, '')::DATE,
       NULLIF($surface_area, '')::NUMERIC
 WHERE $name IS NOT NULL AND $name != ''
   AND ($id IS NULL OR $id = '');

-- Redirect back
SELECT 'redirect' AS component,
       CASE WHEN $id IS NOT NULL AND $id != '' THEN 'property.sql?id=' || $id
            ELSE 'properties.sql' END AS link;
