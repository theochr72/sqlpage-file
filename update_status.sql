-- update_status.sql — Met à jour le statut d'une facture et redirige

-- Audit log: record the status change
INSERT INTO accounting.audit_log (table_name, record_id, action, old_values, new_values)
SELECT 'invoice', id, 'status_change',
       json_build_object('status', status)::JSONB,
       json_build_object('status', $status)::JSONB
  FROM accounting.invoice
 WHERE id = $id::INT
   AND $status IN ('pending_review', 'validated', 'rejected')
   AND status IS DISTINCT FROM $status;

UPDATE accounting.invoice
   SET status = $status
 WHERE id = $id::INT
   AND $status IN ('pending_review', 'validated', 'rejected');

-- Redirect selon le contexte d'appel
-- $return = 'review' + $next → aller à la facture suivante en review
SELECT 'redirect' AS component,
       'review.sql?id=' || $next AS link
 WHERE $return = 'review' AND $next IS NOT NULL AND $next != '';

-- $return = 'review' sans next → retour à la liste pending
SELECT 'redirect' AS component,
       'invoices.sql?status=pending_review' AS link
 WHERE $return = 'review' AND ($next IS NULL OR $next = '');

-- Défaut → retour au détail de la facture
SELECT 'redirect' AS component,
       'invoice.sql?id=' || $id AS link
 WHERE $return IS NULL OR $return != 'review';
