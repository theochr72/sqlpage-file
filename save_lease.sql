-- save_lease.sql — Insert or update a lease

-- Guard: check no overlapping active lease for the same property
SELECT 'redirect' AS component,
       'leases.sql?error=overlap' AS link
 WHERE ($id IS NULL OR $id = '')
   AND EXISTS (
       SELECT 1 FROM accounting.lease
        WHERE property_id = $property_id::INT
          AND end_date IS NULL
          AND ($end_date IS NULL OR $end_date = '')
   );

-- UPDATE existing lease
UPDATE accounting.lease
   SET tenant_id     = $tenant_id::INT,
       property_id   = $property_id::INT,
       start_date    = $start_date::DATE,
       end_date      = NULLIF($end_date, '')::DATE,
       monthly_rent  = $monthly_rent::NUMERIC,
       charges       = COALESCE(NULLIF($charges, '')::NUMERIC, 0),
       deposit       = NULLIF($deposit, '')::NUMERIC,
       revision_date = NULLIF($revision_date, '')::DATE,
       notes         = NULLIF($notes, '')
 WHERE id = $id::INT
   AND $id IS NOT NULL AND $id != '';

-- INSERT new lease
INSERT INTO accounting.lease (tenant_id, property_id, start_date, end_date,
                               monthly_rent, charges, deposit, revision_date, notes)
SELECT $tenant_id::INT,
       $property_id::INT,
       $start_date::DATE,
       NULLIF($end_date, '')::DATE,
       $monthly_rent::NUMERIC,
       COALESCE(NULLIF($charges, '')::NUMERIC, 0),
       NULLIF($deposit, '')::NUMERIC,
       NULLIF($revision_date, '')::DATE,
       NULLIF($notes, '')
 WHERE $tenant_id IS NOT NULL AND $tenant_id != ''
   AND $property_id IS NOT NULL AND $property_id != ''
   AND $start_date IS NOT NULL AND $start_date != ''
   AND ($id IS NULL OR $id = '');

SELECT 'redirect' AS component,
       CASE WHEN $id IS NOT NULL AND $id != '' THEN 'lease.sql?id=' || $id
            ELSE 'leases.sql' END AS link;
