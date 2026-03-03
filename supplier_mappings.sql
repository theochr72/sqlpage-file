-- supplier_mappings.sql — CRUD for auto-categorization rules

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── Breadcrumb ─────────────────────────────────────────────────────────────

SELECT 'breadcrumb' AS component;
SELECT 'Dashboard' AS title, '/' AS link;
SELECT 'Supplier Mappings' AS title, TRUE AS active;

-- ── Success/error feedback ─────────────────────────────────────────────────

SELECT 'alert' AS component,
       'circle-check' AS icon,
       'green' AS color,
       'Mapping saved successfully.' AS title,
       TRUE AS dismissible
 WHERE $saved = '1';

SELECT 'alert' AS component,
       'trash' AS icon,
       'red' AS color,
       'Mapping deleted.' AS title,
       TRUE AS dismissible
 WHERE $deleted = '1';

-- ── Description ────────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Supplier Mappings' AS title,
       'Define auto-categorization rules. When a supplier name matches a pattern, the property and category will be pre-filled on the review and edit pages.' AS description;

-- ── Existing mappings table ────────────────────────────────────────────────

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS hover,
       TRUE AS striped_rows,
       TRUE AS search,
       'No mappings defined yet. Add one below.' AS empty_description;

SELECT sm.supplier_pattern AS "Supplier Pattern",
       COALESCE(c.label, '—') AS "Category",
       COALESCE(p.name, '—') AS "Property",
       to_char(sm.created_at, 'YYYY-MM-DD') AS "Created",
       'delete_supplier_mapping.sql?id=' || sm.id AS "Delete[link]"
  FROM accounting.supplier_mapping sm
  LEFT JOIN accounting.expense_category c ON c.code = sm.category_code
  LEFT JOIN accounting.property p ON p.id = sm.property_id
 ORDER BY sm.supplier_pattern;

-- ── Add / Edit form ────────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Add New Mapping' AS contents, 3 AS size;

SELECT 'form' AS component,
       'POST' AS method,
       'save_supplier_mapping.sql' AS action,
       'Save Mapping' AS validate,
       'plus' AS validate_icon,
       'green' AS validate_color;

SELECT 'text' AS type, 'supplier_pattern' AS name, 'Supplier Pattern' AS label,
       TRUE AS required, 4 AS width,
       'Part of the supplier name to match (case-insensitive). E.g. "leroy" matches "Leroy Merlin".' AS description;

SELECT 'select' AS type, 'category_code' AS name, 'Expense Category' AS label,
       4 AS width, TRUE AS dropdown, TRUE AS empty_option,
       (SELECT json_agg(json_build_object('label', c.label, 'value', c.code) ORDER BY c.sort_order)
          FROM accounting.expense_category c)::TEXT AS options;

SELECT 'select' AS type, 'property_id' AS name, 'Property' AS label,
       4 AS width, TRUE AS dropdown, TRUE AS empty_option,
       (SELECT json_agg(json_build_object('label', p.name || COALESCE(' — ' || p.city, ''), 'value', p.id))
          FROM accounting.property p)::TEXT AS options;
