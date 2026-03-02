-- leases.sql — Lease management with tabs

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'title' AS component, 'Leases' AS contents, 2 AS level;

-- ── Tabs ────────────────────────────────────────────────────────────────────

SELECT 'tab' AS component, TRUE AS center;

SELECT 'Active' AS title,
       'leases.sql?tab=active' || CASE WHEN $property_id IS NOT NULL AND $property_id != '' THEN '&property_id=' || $property_id ELSE '' END AS link,
       (COALESCE($tab, 'active') = 'active') AS active,
       'circle-check' AS icon, 'green' AS color;

SELECT 'Ended' AS title,
       'leases.sql?tab=ended' || CASE WHEN $property_id IS NOT NULL AND $property_id != '' THEN '&property_id=' || $property_id ELSE '' END AS link,
       ($tab = 'ended') AS active,
       'circle-x' AS icon;

SELECT 'All' AS title,
       'leases.sql?tab=all' || CASE WHEN $property_id IS NOT NULL AND $property_id != '' THEN '&property_id=' || $property_id ELSE '' END AS link,
       ($tab = 'all') AS active,
       'list' AS icon;

-- ── Lease table ─────────────────────────────────────────────────────────────

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows, TRUE AS search,
       'Rent,Charges,Deposit' AS align_right,
       'No leases found.' AS empty_description;

SELECT t.name AS "Tenant",
       p.name AS "Property",
       l.start_date::TEXT AS "Start",
       COALESCE(l.end_date::TEXT, '—') AS "End",
       to_char(l.monthly_rent, 'FM999G999D00') || ' €' AS "Rent",
       to_char(l.charges, 'FM999G999D00') || ' €' AS "Charges",
       COALESCE(to_char(l.deposit, 'FM999G999D00') || ' €', '—') AS "Deposit",
       CASE WHEN l.end_date IS NULL THEN 'Active' ELSE 'Ended' END AS "Status",
       CASE WHEN l.end_date IS NULL THEN 'green' ELSE NULL END AS _sqlpage_color,
       'lease.sql?id=' || l.id AS _sqlpage_id
  FROM accounting.lease l
  JOIN accounting.tenant t ON t.id = l.tenant_id
  JOIN accounting.property p ON p.id = l.property_id
 WHERE (COALESCE($tab, 'active') = 'all'
        OR (COALESCE($tab, 'active') = 'active' AND l.end_date IS NULL)
        OR ($tab = 'ended' AND l.end_date IS NOT NULL))
   AND ($property_id IS NULL OR $property_id = '' OR l.property_id = $property_id::INT)
 ORDER BY l.start_date DESC;

-- ── Add lease form ──────────────────────────────────────────────────────────

SELECT 'title' AS component, 'New Lease' AS contents, 3 AS level;

SELECT 'form' AS component,
       'POST' AS method,
       'save_lease.sql' AS action,
       'Add Lease' AS validate,
       'plus' AS validate_icon,
       'green' AS validate_color;

SELECT 'select' AS type, 'tenant_id' AS name, 'Tenant' AS label,
       TRUE AS required, 4 AS width, TRUE AS dropdown, TRUE AS searchable,
       (SELECT json_agg(json_build_object('label', t.name, 'value', t.id) ORDER BY t.name)
          FROM accounting.tenant t)::TEXT AS options;

SELECT 'select' AS type, 'property_id' AS name, 'Property' AS label,
       TRUE AS required, 4 AS width, TRUE AS dropdown, TRUE AS searchable,
       $property_id AS value,
       (SELECT json_agg(json_build_object('label', p.name || COALESCE(' — ' || p.city, ''), 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

SELECT 'date' AS type, 'start_date' AS name, 'Start Date' AS label,
       TRUE AS required, 4 AS width;

SELECT 'date' AS type, 'end_date' AS name, 'End Date' AS label,
       4 AS width, 'Leave empty for ongoing lease' AS description;

SELECT 'number' AS type, 'monthly_rent' AS name, 'Monthly Rent (€)' AS label,
       TRUE AS required, 3 AS width, 0.01 AS step;

SELECT 'number' AS type, 'charges' AS name, 'Charges (€)' AS label,
       3 AS width, 0.01 AS step, '0' AS placeholder;

SELECT 'number' AS type, 'deposit' AS name, 'Deposit (€)' AS label,
       3 AS width, 0.01 AS step;

SELECT 'date' AS type, 'revision_date' AS name, 'Revision Date' AS label, 3 AS width;

SELECT 'textarea' AS type, 'notes' AS name, 'Notes' AS label, 12 AS width, 2 AS rows;
