-- upload.sql — Upload de factures PDF

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'hero' AS component,
       'Import de factures' AS title,
       'Deposez vos factures PDF ici pour une extraction automatique par IA.' AS description;

-- ── Formulaire d'upload ──────────────────────────────────────────────────────

SELECT 'form' AS component,
       'upload_handler.sql' AS action,
       'POST' AS method,
       'multipart/form-data' AS enctype,
       'Importer' AS validate,
       'upload' AS validate_icon,
       'azure' AS validate_color;

SELECT 'file' AS type,
       'invoice_pdf' AS name,
       'Facture PDF' AS label,
       'Selectionnez un fichier PDF' AS placeholder,
       '.pdf' AS accept,
       TRUE AS required,
       'Format accepte : PDF' AS description;

-- ── Steps: comment ça marche ─────────────────────────────────────────────────

SELECT 'title' AS component,
       'Comment ca marche' AS contents,
       3 AS level;

SELECT 'steps' AS component,
       'azure' AS color;

SELECT 'Import PDF' AS title,
       'Deposez votre facture PDF ci-dessus' AS description,
       'upload' AS icon,
       TRUE AS active;

SELECT 'Extraction IA' AS title,
       'Lancez invoice_insert.py pour extraire les donnees par IA' AS description,
       'brain' AS icon;

SELECT 'Verification' AS title,
       'Verifiez les donnees extraites et les scores de confiance' AS description,
       'eye-check' AS icon;

SELECT 'Validation' AS title,
       'Approuvez ou rejetez la facture' AS description,
       'circle-check' AS icon;

-- ── Historique des uploads ───────────────────────────────────────────────────

SELECT 'title' AS component,
       'Historique des imports' AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS hover,
       TRUE AS striped_rows,
       'Aucun fichier importe pour le moment.' AS empty_description;

SELECT filename AS "Fichier",
       to_char(uploaded_at, 'YYYY-MM-DD HH24:MI') AS "Date d''import",
       CASE WHEN processed THEN 'Traite' ELSE 'En attente' END AS "Statut",
       CASE WHEN processed THEN 'green' ELSE 'orange' END AS _sqlpage_color
  FROM accounting.pending_upload
 ORDER BY uploaded_at DESC
 LIMIT 20;
