-- lease.sql — Lease detail page

SELECT 'redirect' AS component, 'leases.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'breadcrumb' AS component;
SELECT 'Dashboard' AS title, '/' AS link;
SELECT 'Leases' AS title, '/leases.sql' AS link;
SELECT t.name || ' — ' || p.name AS title, TRUE AS active
  FROM accounting.lease l
  JOIN accounting.tenant t ON t.id = l.tenant_id
  JOIN accounting.property p ON p.id = l.property_id
 WHERE l.id = $id::INT;

-- ── Lease info ──────────────────────────────────────────────────────────────

SELECT 'datagrid' AS component,
       'Lease #' || l.id AS title,
       CASE WHEN l.end_date IS NULL THEN 'circle-check' ELSE 'circle-x' END AS icon
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Tenant' AS title, t.name AS description,
       'tenant.sql?id=' || t.id AS link, 'user' AS icon
  FROM accounting.lease l JOIN accounting.tenant t ON t.id = l.tenant_id
 WHERE l.id = $id::INT;

SELECT 'Property' AS title, p.name AS description,
       'property.sql?id=' || p.id AS link, 'building' AS icon
  FROM accounting.lease l JOIN accounting.property p ON p.id = l.property_id
 WHERE l.id = $id::INT;

SELECT 'Start Date' AS title, l.start_date::TEXT AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'End Date' AS title, COALESCE(l.end_date::TEXT, 'Ongoing') AS description,
       CASE WHEN l.end_date IS NULL THEN 'green' ELSE NULL END AS color
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Monthly Rent' AS title,
       to_char(l.monthly_rent, 'FM999G999D00') || ' €' AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Charges' AS title,
       to_char(l.charges, 'FM999G999D00') || ' €' AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Total (Rent + Charges)' AS title,
       to_char(l.monthly_rent + l.charges, 'FM999G999D00') || ' €' AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Deposit' AS title,
       COALESCE(to_char(l.deposit, 'FM999G999D00') || ' €', '—') AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Revision Date' AS title, COALESCE(l.revision_date::TEXT, '—') AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Notes' AS title, COALESCE(l.notes, '—') AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

-- ── Buttons ─────────────────────────────────────────────────────────────────

SELECT 'button' AS component, 'start' AS justify, 'sm' AS size;

SELECT 'Record Payment' AS title, 'plus' AS icon, 'green' AS color,
       'rent_form.sql?lease_id=' || $id || '&month=' || EXTRACT(MONTH FROM CURRENT_DATE)::INT
           || '&year=' || EXTRACT(YEAR FROM CURRENT_DATE)::INT AS link;

SELECT 'End Lease' AS title, 'circle-x' AS icon, 'red' AS outline,
       'save_lease.sql?id=' || $id
           || '&tenant_id=' || l.tenant_id
           || '&property_id=' || l.property_id
           || '&start_date=' || l.start_date
           || '&end_date=' || CURRENT_DATE
           || '&monthly_rent=' || l.monthly_rent
           || '&charges=' || l.charges
       AS link
  FROM accounting.lease l WHERE l.id = $id::INT AND l.end_date IS NULL;

-- ── Rent payments ───────────────────────────────────────────────────────────

SELECT 'title' AS component, 'Rent Payments' AS contents, 3 AS level;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Amount' AS align_right,
       'No payments recorded.' AS empty_description;

SELECT to_char(make_date(rp.period_year, rp.period_month, 1), 'Month YYYY') AS "Period",
       rp.payment_date::TEXT AS "Payment Date",
       to_char(rp.amount, 'FM999G999D00') || ' €' AS "Amount",
       INITCAP(rp.payment_method) AS "Method",
       COALESCE(rp.notes, '') AS "Notes",
       'green' AS _sqlpage_color
  FROM accounting.rent_payment rp
 WHERE rp.lease_id = $id::INT
 ORDER BY rp.period_year DESC, rp.period_month DESC;
