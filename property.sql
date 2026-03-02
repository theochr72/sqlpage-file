-- property.sql — Property detail page

SELECT 'redirect' AS component, 'properties.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── Breadcrumb ──────────────────────────────────────────────────────────────

SELECT 'breadcrumb' AS component;
SELECT 'Dashboard' AS title, '/' AS link;
SELECT 'Properties' AS title, '/properties.sql' AS link;
SELECT p.name AS title, TRUE AS active
  FROM accounting.property p WHERE p.id = $id::INT;

-- ── Property Info ───────────────────────────────────────────────────────────

SELECT 'datagrid' AS component,
       p.name AS title,
       CASE p.type
           WHEN 'apartment' THEN 'building'
           WHEN 'house' THEN 'home'
           WHEN 'studio' THEN 'bed'
           WHEN 'parking' THEN 'parking'
           ELSE 'dots' END AS icon
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Address' AS title, COALESCE(p.address, '—') AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'City' AS title, COALESCE(p.city, '—') AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Type' AS title, COALESCE(INITCAP(p.type), '—') AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Surface' AS title, COALESCE(p.surface_area::TEXT || ' m²', '—') AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Purchase Price' AS title, COALESCE(to_char(p.purchase_price, 'FM999G999D00') || ' €', '—') AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Purchase Date' AS title, COALESCE(p.purchase_date::TEXT, '—') AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Monthly Mortgage' AS title, COALESCE(to_char(p.mortgage_monthly, 'FM999G999D00') || ' €', '—') AS description
  FROM accounting.property p WHERE p.id = $id::INT;

SELECT 'Mortgage Period' AS title,
       COALESCE(p.mortgage_start_date::TEXT, '?') || ' → ' || COALESCE(p.mortgage_end_date::TEXT, '?') AS description
  FROM accounting.property p WHERE p.id = $id::INT
   AND (p.mortgage_start_date IS NOT NULL OR p.mortgage_end_date IS NOT NULL);

-- ── Buttons ─────────────────────────────────────────────────────────────────

SELECT 'button' AS component, 'start' AS justify, 'sm' AS size;

SELECT 'Edit' AS title, 'pencil' AS icon, 'azure' AS color,
       'property_edit.sql?id=' || $id AS link;

SELECT 'Add Lease' AS title, 'plus' AS icon, 'green' AS color,
       'leases.sql?property_id=' || $id AS link;

-- ── Active Lease ────────────────────────────────────────────────────────────

SELECT 'title' AS component, 'Active Lease' AS contents, 3 AS level;

SELECT 'alert' AS component,
       'No active lease' AS title,
       'info-circle' AS icon,
       'azure' AS color,
       'leases.sql?property_id=' || $id AS link,
       'Add a lease' AS link_text
 WHERE NOT EXISTS (
     SELECT 1 FROM accounting.lease WHERE property_id = $id::INT AND end_date IS NULL
 );

SELECT 'datagrid' AS component
 WHERE EXISTS (SELECT 1 FROM accounting.lease WHERE property_id = $id::INT AND end_date IS NULL);

SELECT 'Tenant' AS title, t.name AS description,
       'tenant.sql?id=' || t.id AS link, 'user' AS icon
  FROM accounting.lease l
  JOIN accounting.tenant t ON t.id = l.tenant_id
 WHERE l.property_id = $id::INT AND l.end_date IS NULL
 LIMIT 1;

SELECT 'Monthly Rent' AS title,
       to_char(l.monthly_rent, 'FM999G999D00') || ' €' AS description
  FROM accounting.lease l
 WHERE l.property_id = $id::INT AND l.end_date IS NULL
 LIMIT 1;

SELECT 'Charges' AS title,
       to_char(l.charges, 'FM999G999D00') || ' €' AS description
  FROM accounting.lease l
 WHERE l.property_id = $id::INT AND l.end_date IS NULL AND l.charges > 0
 LIMIT 1;

SELECT 'Start Date' AS title, l.start_date::TEXT AS description
  FROM accounting.lease l
 WHERE l.property_id = $id::INT AND l.end_date IS NULL
 LIMIT 1;

SELECT 'Deposit' AS title,
       to_char(l.deposit, 'FM999G999D00') || ' €' AS description
  FROM accounting.lease l
 WHERE l.property_id = $id::INT AND l.end_date IS NULL AND l.deposit IS NOT NULL
 LIMIT 1;

-- ── Lease History ───────────────────────────────────────────────────────────

SELECT 'title' AS component, 'Lease History' AS contents, 3 AS level;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'No leases for this property.' AS empty_description;

SELECT t.name AS "Tenant",
       l.start_date::TEXT AS "Start",
       COALESCE(l.end_date::TEXT, 'Active') AS "End",
       to_char(l.monthly_rent, 'FM999G999D00') || ' €' AS "Rent",
       to_char(l.charges, 'FM999G999D00') || ' €' AS "Charges",
       CASE WHEN l.end_date IS NULL THEN 'green' ELSE NULL END AS _sqlpage_color,
       'lease.sql?id=' || l.id AS _sqlpage_id
  FROM accounting.lease l
  JOIN accounting.tenant t ON t.id = l.tenant_id
 WHERE l.property_id = $id::INT
 ORDER BY l.start_date DESC;

-- ── Invoices ────────────────────────────────────────────────────────────────

SELECT 'title' AS component, 'Invoices' AS contents, 3 AS level;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Amount' AS align_right,
       'No invoices for this property.' AS empty_description;

SELECT i.invoice_number AS "Invoice #",
       i.supplier_name AS "Supplier",
       i.issue_date::TEXT AS "Date",
       COALESCE(to_char(i.total_amount, 'FM999G999D00') || ' €', '') AS "Amount",
       COALESCE(c.label, '') AS "Category",
       CASE WHEN i.status = 'validated' THEN 'green'
            WHEN i.status = 'rejected' THEN 'red'
            ELSE NULL END AS _sqlpage_color,
       'invoice.sql?id=' || i.id AS _sqlpage_id
  FROM accounting.invoice i
  LEFT JOIN accounting.expense_category c ON c.code = i.category_code
 WHERE i.property_id = $id::INT
 ORDER BY i.issue_date DESC;
