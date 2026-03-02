-- upload.sql — Upload de factures PDF

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'hero' AS component,
       'Upload Invoices' AS title,
       'Drop your PDF invoices here for AI-powered data extraction.' AS description;

-- ── Formulaire d'upload ──────────────────────────────────────────────────────

SELECT 'form' AS component,
       'upload_handler.sql' AS action,
       'POST' AS method,
       'multipart/form-data' AS enctype,
       'Upload & Save' AS validate,
       'upload' AS validate_icon,
       'azure' AS validate_color;

SELECT 'file' AS type,
       'invoice_pdf' AS name,
       'PDF Invoice' AS label,
       'Select a PDF file to upload' AS placeholder,
       '.pdf' AS accept,
       TRUE AS required,
       'Supported format: PDF' AS description;

-- ── Steps: comment ça marche ─────────────────────────────────────────────────

SELECT 'title' AS component,
       'How it works' AS contents,
       3 AS level;

SELECT 'steps' AS component,
       'azure' AS color;

SELECT 'Upload PDF' AS title,
       'Drop your invoice PDF above' AS description,
       'upload' AS icon,
       TRUE AS active;

SELECT 'AI Extraction' AS title,
       'Run invoice_insert.py to extract data with AI' AS description,
       'brain' AS icon;

SELECT 'Review' AS title,
       'Check extracted data and confidence scores' AS description,
       'eye-check' AS icon;

SELECT 'Validate' AS title,
       'Approve or reject the invoice' AS description,
       'circle-check' AS icon;

-- ── Historique des uploads ───────────────────────────────────────────────────

SELECT 'title' AS component,
       'Upload History' AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS hover,
       TRUE AS striped_rows,
       'No files uploaded yet.' AS empty_description;

SELECT filename AS "Filename",
       to_char(uploaded_at, 'YYYY-MM-DD HH24:MI') AS "Uploaded",
       CASE WHEN processed THEN 'Processed' ELSE 'Pending' END AS "Status",
       CASE WHEN processed THEN 'green' ELSE 'orange' END AS _sqlpage_color
  FROM accounting.pending_upload
 ORDER BY uploaded_at DESC
 LIMIT 20;
