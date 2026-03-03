-- upload_handler.sql — Traite l'upload de fichiers PDF

-- Persiste le fichier uploadé dans le dossier uploads/
SET file_path = sqlpage.persist_uploaded_file('invoice_pdf', 'uploads', 'pdf');

-- Enregistre dans la table pending_upload si un fichier a été reçu
INSERT INTO accounting.pending_upload (filename, file_path)
SELECT sqlpage.uploaded_file_name('invoice_pdf'),
       $file_path
 WHERE $file_path IS NOT NULL;

-- Succès : redirige vers la page upload
SELECT 'redirect' AS component,
       'upload.sql' AS link
 WHERE $file_path IS NOT NULL;

-- Erreur : affiche un message inline (pas de double redirect)
SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties
 WHERE $file_path IS NULL;

SELECT 'alert' AS component,
       'Echec de l''import' AS title,
       'alert-circle' AS icon,
       'red' AS color,
       'Le fichier n''a pas pu etre enregistre. Verifiez que vous avez selectionne un fichier PDF valide.' AS description,
       TRUE AS important
 WHERE $file_path IS NULL;

SELECT 'button' AS component, 'center' AS justify
 WHERE $file_path IS NULL;

SELECT 'Reessayer' AS title,
       'upload' AS icon,
       'azure' AS color,
       '/upload.sql' AS link
 WHERE $file_path IS NULL;
