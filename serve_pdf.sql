-- serve_pdf.sql — Sert le PDF original d'une facture pour affichage inline (iframe)

-- Guard : id invalide → 404
SELECT 'status_code' AS component, 404 AS status
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';
SELECT 'redirect' AS component, 'invoices.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

-- Construire le chemin du fichier
SET _renamed = (SELECT renamed_filename FROM accounting.invoice WHERE id = $id::INT);
SET _original = (SELECT original_filename FROM accounting.invoice WHERE id = $id::INT);
SET _filename = COALESCE($_renamed, $_original);
SET _path = 'uploads/' || $_filename;
SET _data_url = sqlpage.read_file_as_data_url($_path);

-- Servir le PDF si trouvé
SELECT 'http_header' AS component,
       'application/pdf' AS "Content-Type",
       'inline; filename="' || $_filename || '"' AS "Content-Disposition"
 WHERE $_data_url IS NOT NULL;

SELECT 'download' AS component,
       $_data_url AS data_url,
       $_filename AS filename
 WHERE $_data_url IS NOT NULL;

-- Fichier introuvable → 404 avec message
SELECT 'status_code' AS component, 404 AS status
 WHERE $_data_url IS NULL;

SELECT 'html' AS component
 WHERE $_data_url IS NULL;
SELECT '<p style="padding:1em;color:#666">PDF introuvable&nbsp;: <code>' || $_path || '</code></p>' AS html
 WHERE $_data_url IS NULL;
