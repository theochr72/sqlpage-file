-- tenants.sql — Tenant management

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'title' AS component, 'Tenants' AS contents, 2 AS level;

-- ── Add tenant form ─────────────────────────────────────────────────────────

SELECT 'form' AS component,
       'POST' AS method,
       'save_tenant.sql' AS action,
       'Add Tenant' AS validate,
       'plus' AS validate_icon,
       'azure' AS validate_color,
       'New Tenant' AS title;

SELECT 'text' AS type, 'name' AS name, 'Name' AS label,
       TRUE AS required, 4 AS width;

SELECT 'email' AS type, 'email' AS name, 'Email' AS label, 4 AS width;

SELECT 'tel' AS type, 'phone' AS name, 'Phone' AS label, 4 AS width;

SELECT 'textarea' AS type, 'notes' AS name, 'Notes' AS label, 12 AS width, 2 AS rows;

-- ── Tenant list ─────────────────────────────────────────────────────────────

SELECT 'card' AS component, 3 AS columns;

SELECT t.name AS title,
       COALESCE(t.email, '') AS description,
       COALESCE(t.phone, '') AS footer,
       'user' AS icon,
       'tenant.sql?id=' || t.id AS link,
       COALESCE(
           (SELECT p.name FROM accounting.lease l
              JOIN accounting.property p ON p.id = l.property_id
             WHERE l.tenant_id = t.id AND l.end_date IS NULL
             LIMIT 1),
           'No active lease'
       ) AS footer_md
  FROM accounting.tenant t
 ORDER BY t.name;
