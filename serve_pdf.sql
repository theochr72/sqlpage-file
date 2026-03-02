-- serve_pdf.sql — Sert le PDF original d'une facture pour affichage inline (iframe)

-- Guard : id invalide → 404
SELECT 'status_code' AS component, 404 AS status
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';
SELECT 'redirect' AS component, 'invoices.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

-- Headers pour affichage inline
SELECT 'http_header' AS component,
       'application/pdf' AS "Content-Type",
       'inline; filename="' || i.renamed_filename || '"' AS "Content-Disposition"
  FROM accounting.invoice i
 WHERE i.id = $id::INT AND i.renamed_filename IS NOT NULL;

-- Servir le fichier
SELECT 'download' AS component,
       sqlpage.read_file_as_data_url('uploads/' || i.renamed_filename) AS data_url,
       i.renamed_filename AS filename
  FROM accounting.invoice i
 WHERE i.id = $id::INT AND i.renamed_filename IS NOT NULL;
