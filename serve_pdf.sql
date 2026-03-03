-- serve_pdf.sql — Sert le PDF original d'une facture pour affichage inline (iframe)

-- Guard : id invalide → 404
SELECT 'status_code' AS component, 404 AS status
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';
SELECT 'redirect' AS component, 'invoices.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

-- Essai 1 : uploads/<renamed_filename>
SET _data_url = (
    SELECT sqlpage.read_file_as_data_url('uploads/' || i.renamed_filename)
      FROM accounting.invoice i
     WHERE i.id = $id::INT AND i.renamed_filename IS NOT NULL
);

-- Essai 2 : uploads/<original_filename>  (fallback si pas renommé)
SET _data_url = COALESCE($_data_url, (
    SELECT sqlpage.read_file_as_data_url('uploads/' || i.original_filename)
      FROM accounting.invoice i
     WHERE i.id = $id::INT AND i.original_filename IS NOT NULL
));

-- Servir le PDF si trouvé
SELECT 'http_header' AS component,
       'application/pdf' AS "Content-Type",
       'inline; filename="' || COALESCE(i.renamed_filename, i.original_filename) || '"' AS "Content-Disposition"
  FROM accounting.invoice i
 WHERE i.id = $id::INT AND $_data_url IS NOT NULL;

SELECT 'download' AS component,
       $_data_url AS data_url,
       COALESCE(i.renamed_filename, i.original_filename) AS filename
  FROM accounting.invoice i
 WHERE i.id = $id::INT AND $_data_url IS NOT NULL;

-- Fichier introuvable → 404 avec message
SELECT 'status_code' AS component, 404 AS status
 WHERE $_data_url IS NULL;

SELECT 'html' AS component
 WHERE $_data_url IS NULL;
SELECT '<p style="padding:1em;color:#666">PDF introuvable&nbsp;: <code>uploads/' || COALESCE(i.renamed_filename, i.original_filename, '?') || '</code></p>' AS html
  FROM accounting.invoice i
 WHERE i.id = $id::INT AND $_data_url IS NULL;
