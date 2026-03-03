-- save_invoice.sql — Sauvegarde les modifications manuelles d'une facture

-- Guard: no id → back to list
SELECT 'redirect' AS component, 'invoices.sql' AS link
 WHERE $id IS NULL OR $id = '';

-- Audit log
INSERT INTO accounting.audit_log (table_name, record_id, action, old_values, new_values)
SELECT 'invoice', id, 'manual_edit',
       json_build_object(
           'invoice_number', invoice_number,
           'status', status,
           'total_amount', total_amount,
           'category_code', category_code,
           'property_id', property_id
       )::JSONB,
       json_build_object(
           'invoice_number', $invoice_number,
           'status', $status,
           'total_amount', $total_amount,
           'category_code', NULLIF($category_code, ''),
           'property_id', NULLIF($property_id, '')
       )::JSONB
  FROM accounting.invoice WHERE id = $id::INT;

UPDATE accounting.invoice
   SET invoice_number   = $invoice_number,
       document_type    = NULLIF($document_type, ''),
       issue_date       = NULLIF($issue_date, '')::DATE,
       due_date         = NULLIF($due_date, '')::DATE,
       supplier_name    = NULLIF($supplier_name, ''),
       supplier_vat_id  = NULLIF($supplier_vat_id, ''),
       supplier_address = NULLIF($supplier_address, ''),
       customer_name    = NULLIF($customer_name, ''),
       customer_address = NULLIF($customer_address, ''),
       total_amount     = NULLIF($total_amount, '')::NUMERIC,
       total_ht         = NULLIF($total_ht, '')::NUMERIC,
       tva_amount       = NULLIF($tva_amount, '')::NUMERIC,
       currency         = NULLIF($currency, ''),
       status           = $status,
       -- LMNP fields
       property_id      = NULLIF($property_id, '')::INT,
       category_code    = NULLIF($category_code, ''),
       fiscal_year      = NULLIF($fiscal_year, '')::INT,
       notes            = NULLIF($notes, ''),
       -- Edit tracking
       manually_edited_at = now(),
       manually_edited_fields = ARRAY(
           SELECT field FROM (
               VALUES
                   (CASE WHEN invoice_number IS DISTINCT FROM $invoice_number THEN 'invoice_number' END),
                   (CASE WHEN document_type IS DISTINCT FROM NULLIF($document_type, '') THEN 'document_type' END),
                   (CASE WHEN issue_date::TEXT IS DISTINCT FROM NULLIF($issue_date, '') THEN 'issue_date' END),
                   (CASE WHEN due_date::TEXT IS DISTINCT FROM NULLIF($due_date, '') THEN 'due_date' END),
                   (CASE WHEN supplier_name IS DISTINCT FROM NULLIF($supplier_name, '') THEN 'supplier_name' END),
                   (CASE WHEN supplier_vat_id IS DISTINCT FROM NULLIF($supplier_vat_id, '') THEN 'supplier_vat_id' END),
                   (CASE WHEN supplier_address IS DISTINCT FROM NULLIF($supplier_address, '') THEN 'supplier_address' END),
                   (CASE WHEN customer_name IS DISTINCT FROM NULLIF($customer_name, '') THEN 'customer_name' END),
                   (CASE WHEN customer_address IS DISTINCT FROM NULLIF($customer_address, '') THEN 'customer_address' END),
                   (CASE WHEN total_amount::TEXT IS DISTINCT FROM NULLIF($total_amount, '') THEN 'total_amount' END),
                   (CASE WHEN total_ht::TEXT IS DISTINCT FROM NULLIF($total_ht, '') THEN 'total_ht' END),
                   (CASE WHEN tva_amount::TEXT IS DISTINCT FROM NULLIF($tva_amount, '') THEN 'tva_amount' END),
                   (CASE WHEN currency IS DISTINCT FROM NULLIF($currency, '') THEN 'currency' END),
                   (CASE WHEN status IS DISTINCT FROM $status THEN 'status' END),
                   (CASE WHEN property_id::TEXT IS DISTINCT FROM NULLIF($property_id, '') THEN 'property_id' END),
                   (CASE WHEN category_code IS DISTINCT FROM NULLIF($category_code, '') THEN 'category_code' END),
                   (CASE WHEN fiscal_year::TEXT IS DISTINCT FROM NULLIF($fiscal_year, '') THEN 'fiscal_year' END),
                   (CASE WHEN notes IS DISTINCT FROM NULLIF($notes, '') THEN 'notes' END)
           ) AS t(field)
           WHERE field IS NOT NULL
       )
 WHERE id = $id::INT;

SELECT 'redirect' AS component,
       'invoice.sql?id=' || $id || '&saved=1' AS link;
