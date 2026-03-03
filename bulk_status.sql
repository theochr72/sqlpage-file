-- bulk_status.sql — Bulk validate or reject pending invoices

-- Guard: need valid action
SELECT 'redirect' AS component, 'invoices.sql' AS link
 WHERE $action IS NULL OR $action NOT IN ('validate', 'reject');

-- Audit log for bulk action
INSERT INTO accounting.audit_log (table_name, record_id, action, old_values, new_values)
SELECT 'invoice', id, 'bulk_action',
       json_build_object('status', status)::JSONB,
       json_build_object('status',
           CASE WHEN $action = 'validate' THEN 'validated' ELSE 'rejected' END
       )::JSONB
  FROM accounting.invoice
 WHERE status = 'pending_review'
   AND ($min_confidence IS NULL OR $min_confidence = ''
        OR overall_confidence >= $min_confidence::NUMERIC)
   AND ($max_confidence IS NULL OR $max_confidence = ''
        OR overall_confidence < $max_confidence::NUMERIC);

-- Perform the bulk update
UPDATE accounting.invoice
   SET status = CASE WHEN $action = 'validate' THEN 'validated' ELSE 'rejected' END
 WHERE status = 'pending_review'
   AND ($min_confidence IS NULL OR $min_confidence = ''
        OR overall_confidence >= $min_confidence::NUMERIC)
   AND ($max_confidence IS NULL OR $max_confidence = ''
        OR overall_confidence < $max_confidence::NUMERIC);

SELECT 'redirect' AS component,
       'invoices.sql?status=' || CASE WHEN $action = 'validate' THEN 'validated' ELSE 'rejected' END AS link;
