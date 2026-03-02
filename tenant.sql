-- tenant.sql — Tenant detail page

SELECT 'redirect' AS component, 'tenants.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'breadcrumb' AS component;
SELECT 'Dashboard' AS title, '/' AS link;
SELECT 'Tenants' AS title, '/tenants.sql' AS link;
SELECT t.name AS title, TRUE AS active
  FROM accounting.tenant t WHERE t.id = $id::INT;

-- ── Contact info ────────────────────────────────────────────────────────────

SELECT 'datagrid' AS component,
       t.name AS title, 'user' AS icon
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'Email' AS title, COALESCE(t.email, '—') AS description, 'mail' AS icon
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'Phone' AS title, COALESCE(t.phone, '—') AS description, 'phone' AS icon
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'Notes' AS title, COALESCE(t.notes, '—') AS description
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'Created' AS title, to_char(t.created_at, 'YYYY-MM-DD') AS description
  FROM accounting.tenant t WHERE t.id = $id::INT;

-- ── Edit form ───────────────────────────────────────────────────────────────

SELECT 'form' AS component,
       'POST' AS method,
       'save_tenant.sql?id=' || $id AS action,
       'Save' AS validate,
       'device-floppy' AS validate_icon,
       'green' AS validate_color,
       'Edit Tenant' AS title;

SELECT 'text' AS type, 'name' AS name, 'Name' AS label,
       t.name AS value, TRUE AS required, 4 AS width
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'email' AS type, 'email' AS name, 'Email' AS label,
       t.email AS value, 4 AS width
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'tel' AS type, 'phone' AS name, 'Phone' AS label,
       t.phone AS value, 4 AS width
  FROM accounting.tenant t WHERE t.id = $id::INT;

SELECT 'textarea' AS type, 'notes' AS name, 'Notes' AS label,
       t.notes AS value, 12 AS width, 2 AS rows
  FROM accounting.tenant t WHERE t.id = $id::INT;

-- ── Lease history ───────────────────────────────────────────────────────────

SELECT 'title' AS component, 'Lease History' AS contents, 3 AS level;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'No leases for this tenant.' AS empty_description;

SELECT p.name AS "Property",
       l.start_date::TEXT AS "Start",
       COALESCE(l.end_date::TEXT, 'Active') AS "End",
       to_char(l.monthly_rent, 'FM999G999D00') || ' €' AS "Rent",
       to_char(l.charges, 'FM999G999D00') || ' €' AS "Charges",
       CASE WHEN l.end_date IS NULL THEN 'green' ELSE NULL END AS _sqlpage_color,
       'lease.sql?id=' || l.id AS _sqlpage_id
  FROM accounting.lease l
  JOIN accounting.property p ON p.id = l.property_id
 WHERE l.tenant_id = $id::INT
 ORDER BY l.start_date DESC;
