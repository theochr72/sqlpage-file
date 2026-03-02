-- rent_form.sql — Record a rent payment

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'breadcrumb' AS component;
SELECT 'Dashboard' AS title, '/' AS link;
SELECT 'Rent' AS title, '/rent.sql' AS link;
SELECT 'Record Payment' AS title, TRUE AS active;

SELECT 'form' AS component,
       'POST' AS method,
       'save_rent.sql' AS action,
       'Save Payment' AS validate,
       'device-floppy' AS validate_icon,
       'green' AS validate_color,
       'Record Rent Payment' AS title;

SELECT 'select' AS type, 'lease_id' AS name, 'Lease' AS label,
       TRUE AS required, 6 AS width, TRUE AS dropdown, TRUE AS searchable,
       $lease_id AS value,
       (SELECT json_agg(json_build_object(
           'label', t.name || ' — ' || p.name || ' (' || to_char(l.monthly_rent + l.charges, 'FM999G999D00') || ' €)',
           'value', l.id
       ) ORDER BY p.name)
          FROM accounting.lease l
          JOIN accounting.tenant t ON t.id = l.tenant_id
          JOIN accounting.property p ON p.id = l.property_id
         WHERE l.end_date IS NULL OR l.end_date >= CURRENT_DATE
       )::TEXT AS options;

SELECT 'select' AS type, 'period_month' AS name, 'Month' AS label,
       TRUE AS required, 3 AS width, TRUE AS dropdown,
       COALESCE($month, EXTRACT(MONTH FROM CURRENT_DATE)::TEXT) AS value,
       '[{"label":"January","value":"1"},{"label":"February","value":"2"},{"label":"March","value":"3"},{"label":"April","value":"4"},{"label":"May","value":"5"},{"label":"June","value":"6"},{"label":"July","value":"7"},{"label":"August","value":"8"},{"label":"September","value":"9"},{"label":"October","value":"10"},{"label":"November","value":"11"},{"label":"December","value":"12"}]' AS options;

SELECT 'number' AS type, 'period_year' AS name, 'Year' AS label,
       TRUE AS required, 3 AS width,
       COALESCE($year, EXTRACT(YEAR FROM CURRENT_DATE)::TEXT) AS value;

SELECT 'number' AS type, 'amount' AS name, 'Amount (€)' AS label,
       TRUE AS required, 4 AS width, 0.01 AS step,
       COALESCE(
           (SELECT (l.monthly_rent + l.charges)::TEXT FROM accounting.lease l WHERE l.id = $lease_id::INT),
           ''
       ) AS value;

SELECT 'date' AS type, 'payment_date' AS name, 'Payment Date' AS label,
       TRUE AS required, 4 AS width,
       CURRENT_DATE::TEXT AS value;

SELECT 'select' AS type, 'payment_method' AS name, 'Method' AS label,
       4 AS width, TRUE AS dropdown,
       'transfer' AS value,
       '[{"label":"Transfer","value":"transfer"},{"label":"Check","value":"check"},{"label":"Cash","value":"cash"},{"label":"Other","value":"other"}]' AS options;

SELECT 'textarea' AS type, 'notes' AS name, 'Notes' AS label, 12 AS width, 2 AS rows;
