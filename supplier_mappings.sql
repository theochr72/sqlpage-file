-- supplier_mappings.sql — Gestion des regles d'auto-categorisation

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── Breadcrumb ─────────────────────────────────────────────────────────────

SELECT 'breadcrumb' AS component;
SELECT 'Tableau de bord' AS title, '/' AS link;
SELECT 'Correspondances fournisseurs' AS title, TRUE AS active;

-- ── Retour succes/erreur ─────────────────────────────────────────────────

SELECT 'alert' AS component,
       'circle-check' AS icon,
       'green' AS color,
       'Correspondance enregistree.' AS title,
       TRUE AS dismissible
 WHERE $saved = '1';

SELECT 'alert' AS component,
       'trash' AS icon,
       'red' AS color,
       'Correspondance supprimee.' AS title,
       TRUE AS dismissible
 WHERE $deleted = '1';

-- ── Description ────────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Correspondances fournisseurs' AS title,
       'Definissez des regles d''auto-categorisation. Quand le nom d''un fournisseur correspond a un motif, le bien et la categorie seront pre-remplis sur les pages de verification et d''edition.' AS description;

-- ── Tableau des correspondances existantes ───────────────────────────────

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS hover,
       TRUE AS striped_rows,
       TRUE AS search,
       'Aucune correspondance definie. Ajoutez-en une ci-dessous.' AS empty_description;

SELECT sm.supplier_pattern AS "Motif fournisseur",
       COALESCE(c.label, '—') AS "Categorie",
       COALESCE(p.name, '—') AS "Bien",
       to_char(sm.created_at, 'YYYY-MM-DD') AS "Cree le",
       'delete_supplier_mapping.sql?id=' || sm.id AS "Supprimer[link]"
  FROM accounting.supplier_mapping sm
  LEFT JOIN accounting.expense_category c ON c.code = sm.category_code
  LEFT JOIN accounting.property p ON p.id = sm.property_id
 ORDER BY sm.supplier_pattern;

-- ── Formulaire d'ajout ───────────────────────────────────────────────────

SELECT 'divider' AS component, 'Ajouter une correspondance' AS contents, 3 AS size;

SELECT 'form' AS component,
       'POST' AS method,
       'save_supplier_mapping.sql' AS action,
       'Enregistrer' AS validate,
       'plus' AS validate_icon,
       'green' AS validate_color;

SELECT 'text' AS type, 'supplier_pattern' AS name, 'Motif fournisseur' AS label,
       TRUE AS required, 4 AS width,
       'Partie du nom du fournisseur a reconnaitre (insensible a la casse). Ex: "leroy" correspond a "Leroy Merlin".' AS description;

SELECT 'select' AS type, 'category_code' AS name, 'Categorie de depense' AS label,
       4 AS width, TRUE AS dropdown, TRUE AS empty_option,
       (SELECT json_agg(json_build_object('label', c.label, 'value', c.code) ORDER BY c.sort_order)
          FROM accounting.expense_category c)::TEXT AS options;

SELECT 'select' AS type, 'property_id' AS name, 'Bien' AS label,
       4 AS width, TRUE AS dropdown, TRUE AS empty_option,
       (SELECT json_agg(json_build_object('label', p.name || COALESCE(' — ' || p.city, ''), 'value', p.id))
          FROM accounting.property p)::TEXT AS options;
