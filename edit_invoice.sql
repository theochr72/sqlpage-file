-- edit_invoice.sql — Formulaire d'édition manuelle d'une facture

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- Redirect si pas d'id valide
SELECT 'redirect' AS component, 'invoices.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

-- ── Breadcrumb ───────────────────────────────────────────────────────────────

SELECT 'breadcrumb' AS component;

SELECT 'Tableau de bord' AS title, '/' AS link;
SELECT 'Factures' AS title, '/invoices.sql' AS link;
SELECT i.invoice_number AS title, 'invoice.sql?id=' || $id AS link
  FROM accounting.invoice i WHERE i.id = $id::INT;
SELECT 'Modifier' AS title, TRUE AS active;

-- ── Alerte si déjà édité manuellement ────────────────────────────────────────

SELECT 'alert' AS component,
       'info' AS icon,
       'azure' AS color,
       'Derniere modification manuelle : ' || to_char(i.manually_edited_at, 'YYYY-MM-DD HH24:MI') AS title,
       'Champs : ' || array_to_string(i.manually_edited_fields, ', ') AS description,
       TRUE AS dismissible
  FROM accounting.invoice i
 WHERE i.id = $id::INT AND i.manually_edited_at IS NOT NULL;

-- ── Formulaire d'édition ─────────────────────────────────────────────────────

SELECT 'form' AS component,
       'POST' AS method,
       'save_invoice.sql' AS action,
       'Enregistrer' AS validate,
       'device-floppy' AS validate_icon,
       'green' AS validate_color,
       'Annuler' AS reset,
       'Informations de la facture' AS title;

SELECT 'hidden' AS type, 'id' AS name, $id AS value;

SELECT 'text' AS type, 'invoice_number' AS name, 'Numero de facture' AS label,
       i.invoice_number AS value, TRUE AS required, 4 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'document_type' AS name, 'Type de document' AS label,
       i.document_type AS value, 4 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'select' AS type, 'status' AS name, 'Statut' AS label,
       i.status AS value, 4 AS width,
       '[{"label":"En attente","value":"pending_review"},{"label":"Validee","value":"validated"},{"label":"Rejetee","value":"rejected"}]' AS options
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'date' AS type, 'issue_date' AS name, 'Date d''emission' AS label,
       i.issue_date::TEXT AS value, 6 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'date' AS type, 'due_date' AS name, 'Date d''echeance' AS label,
       i.due_date::TEXT AS value, 6 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'supplier_name' AS name, 'Nom du fournisseur' AS label,
       i.supplier_name AS value, 'building' AS prefix_icon, 6 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'supplier_vat_id' AS name, 'N° TVA fournisseur' AS label,
       i.supplier_vat_id AS value, 6 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'textarea' AS type, 'supplier_address' AS name, 'Adresse fournisseur' AS label,
       i.supplier_address AS value, 2 AS rows, 6 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'customer_name' AS name, 'Nom du client' AS label,
       i.customer_name AS value, 'user' AS prefix_icon, 6 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'textarea' AS type, 'customer_address' AS name, 'Adresse client' AS label,
       i.customer_address AS value, 2 AS rows, 6 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'number' AS type, 'total_amount' AS name, 'Montant total (TTC)' AS label,
       i.total_amount::TEXT AS value, 0.01 AS step, 4 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'number' AS type, 'total_ht' AS name, 'Total HT' AS label,
       i.total_ht::TEXT AS value, 0.01 AS step, 4 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'number' AS type, 'tva_amount' AS name, 'Montant TVA' AS label,
       i.tva_amount::TEXT AS value, 0.01 AS step, 2 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'text' AS type, 'currency' AS name, 'Devise' AS label,
       i.currency AS value, 2 AS width, 3 AS maxlength
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Champs LMNP ─────────────────────────────────────────────────────────────

SELECT 'divider' AS component, 'LMNP' AS contents;

-- Auto-suggest property from supplier_mapping
SET _auto_property = (
    SELECT sm.property_id::TEXT
      FROM accounting.supplier_mapping sm
      JOIN accounting.invoice i ON i.id = $id::INT
     WHERE i.supplier_name ILIKE '%' || sm.supplier_pattern || '%'
       AND i.property_id IS NULL
     LIMIT 1
);

-- Auto-suggest category from supplier_mapping
SET _auto_category = (
    SELECT sm.category_code
      FROM accounting.supplier_mapping sm
      JOIN accounting.invoice i ON i.id = $id::INT
     WHERE i.supplier_name ILIKE '%' || sm.supplier_pattern || '%'
       AND i.category_code IS NULL
     LIMIT 1
);

SELECT 'select' AS type, 'property_id' AS name, 'Bien' AS label,
       COALESCE(i.property_id::TEXT, $_auto_property) AS value, 4 AS width, TRUE AS dropdown,
       CASE WHEN i.property_id IS NULL AND $_auto_property IS NOT NULL THEN 'Suggestion automatique depuis le fournisseur' END AS description,
       (SELECT json_agg(json_build_object('label', p.name || COALESCE(' — ' || p.city, ''), 'value', p.id))
          FROM accounting.property p)::TEXT AS options
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'select' AS type, 'category_code' AS name, 'Categorie de depense' AS label,
       COALESCE(i.category_code, $_auto_category) AS value, 4 AS width, TRUE AS dropdown,
       CASE WHEN i.category_code IS NULL AND $_auto_category IS NOT NULL THEN 'Suggestion automatique depuis le fournisseur' END AS description,
       (SELECT json_agg(json_build_object('label', c.label, 'value', c.code) ORDER BY c.sort_order)
          FROM accounting.expense_category c)::TEXT AS options
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'number' AS type, 'fiscal_year' AS name, 'Annee fiscale' AS label,
       COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date))::TEXT AS value,
       1 AS step, 2 AS width
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'textarea' AS type, 'notes' AS name, 'Notes' AS label,
       i.notes AS value, 3 AS rows, 12 AS width,
       'Notes internes, contexte, etc.' AS placeholder
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Bouton retour ────────────────────────────────────────────────────────────

SELECT 'button' AS component, 'start' AS justify;

SELECT 'Annuler' AS title,
       'arrow-left' AS icon,
       'invoice.sql?id=' || $id AS link;
