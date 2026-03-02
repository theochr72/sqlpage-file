-- update_status.sql — Met à jour le statut d'une facture et redirige

UPDATE accounting.invoice
   SET status = $status
 WHERE id = $id::INT
   AND $status IN ('pending_review', 'validated', 'rejected');

SELECT 'redirect' AS component,
       'invoice.sql?id=' || $id AS link;
