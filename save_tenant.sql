-- save_tenant.sql — Insert or update a tenant

UPDATE accounting.tenant
   SET name  = $name,
       email = NULLIF($email, ''),
       phone = NULLIF($phone, ''),
       notes = NULLIF($notes, '')
 WHERE id = $id::INT
   AND $id IS NOT NULL AND $id != '';

INSERT INTO accounting.tenant (name, email, phone, notes)
SELECT $name, NULLIF($email, ''), NULLIF($phone, ''), NULLIF($notes, '')
 WHERE $name IS NOT NULL AND $name != ''
   AND ($id IS NULL OR $id = '');

SELECT 'redirect' AS component,
       CASE WHEN $id IS NOT NULL AND $id != '' THEN 'tenant.sql?id=' || $id
            ELSE 'tenants.sql' END AS link;
