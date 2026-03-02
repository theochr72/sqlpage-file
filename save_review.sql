-- save_review.sql — Sauvegarde les modifications depuis la page de review

-- ── Update invoice header ──────────────────────────────────────────────────

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

-- ── Update invoice items (1..20, conditioned on desc_N not null) ───────────

UPDATE accounting.invoice_item SET
    description = $desc_1,
    quantity    = NULLIF($qty_1, '')::NUMERIC,
    unit_price  = NULLIF($price_1, '')::NUMERIC,
    total       = NULLIF($item_total_1, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 1 AND $desc_1 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_2,
    quantity    = NULLIF($qty_2, '')::NUMERIC,
    unit_price  = NULLIF($price_2, '')::NUMERIC,
    total       = NULLIF($item_total_2, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 2 AND $desc_2 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_3,
    quantity    = NULLIF($qty_3, '')::NUMERIC,
    unit_price  = NULLIF($price_3, '')::NUMERIC,
    total       = NULLIF($item_total_3, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 3 AND $desc_3 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_4,
    quantity    = NULLIF($qty_4, '')::NUMERIC,
    unit_price  = NULLIF($price_4, '')::NUMERIC,
    total       = NULLIF($item_total_4, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 4 AND $desc_4 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_5,
    quantity    = NULLIF($qty_5, '')::NUMERIC,
    unit_price  = NULLIF($price_5, '')::NUMERIC,
    total       = NULLIF($item_total_5, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 5 AND $desc_5 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_6,
    quantity    = NULLIF($qty_6, '')::NUMERIC,
    unit_price  = NULLIF($price_6, '')::NUMERIC,
    total       = NULLIF($item_total_6, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 6 AND $desc_6 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_7,
    quantity    = NULLIF($qty_7, '')::NUMERIC,
    unit_price  = NULLIF($price_7, '')::NUMERIC,
    total       = NULLIF($item_total_7, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 7 AND $desc_7 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_8,
    quantity    = NULLIF($qty_8, '')::NUMERIC,
    unit_price  = NULLIF($price_8, '')::NUMERIC,
    total       = NULLIF($item_total_8, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 8 AND $desc_8 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_9,
    quantity    = NULLIF($qty_9, '')::NUMERIC,
    unit_price  = NULLIF($price_9, '')::NUMERIC,
    total       = NULLIF($item_total_9, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 9 AND $desc_9 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_10,
    quantity    = NULLIF($qty_10, '')::NUMERIC,
    unit_price  = NULLIF($price_10, '')::NUMERIC,
    total       = NULLIF($item_total_10, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 10 AND $desc_10 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_11,
    quantity    = NULLIF($qty_11, '')::NUMERIC,
    unit_price  = NULLIF($price_11, '')::NUMERIC,
    total       = NULLIF($item_total_11, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 11 AND $desc_11 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_12,
    quantity    = NULLIF($qty_12, '')::NUMERIC,
    unit_price  = NULLIF($price_12, '')::NUMERIC,
    total       = NULLIF($item_total_12, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 12 AND $desc_12 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_13,
    quantity    = NULLIF($qty_13, '')::NUMERIC,
    unit_price  = NULLIF($price_13, '')::NUMERIC,
    total       = NULLIF($item_total_13, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 13 AND $desc_13 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_14,
    quantity    = NULLIF($qty_14, '')::NUMERIC,
    unit_price  = NULLIF($price_14, '')::NUMERIC,
    total       = NULLIF($item_total_14, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 14 AND $desc_14 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_15,
    quantity    = NULLIF($qty_15, '')::NUMERIC,
    unit_price  = NULLIF($price_15, '')::NUMERIC,
    total       = NULLIF($item_total_15, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 15 AND $desc_15 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_16,
    quantity    = NULLIF($qty_16, '')::NUMERIC,
    unit_price  = NULLIF($price_16, '')::NUMERIC,
    total       = NULLIF($item_total_16, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 16 AND $desc_16 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_17,
    quantity    = NULLIF($qty_17, '')::NUMERIC,
    unit_price  = NULLIF($price_17, '')::NUMERIC,
    total       = NULLIF($item_total_17, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 17 AND $desc_17 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_18,
    quantity    = NULLIF($qty_18, '')::NUMERIC,
    unit_price  = NULLIF($price_18, '')::NUMERIC,
    total       = NULLIF($item_total_18, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 18 AND $desc_18 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_19,
    quantity    = NULLIF($qty_19, '')::NUMERIC,
    unit_price  = NULLIF($price_19, '')::NUMERIC,
    total       = NULLIF($item_total_19, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 19 AND $desc_19 IS NOT NULL;

UPDATE accounting.invoice_item SET
    description = $desc_20,
    quantity    = NULLIF($qty_20, '')::NUMERIC,
    unit_price  = NULLIF($price_20, '')::NUMERIC,
    total       = NULLIF($item_total_20, '')::NUMERIC
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
   AND item_index = 20 AND $desc_20 IS NOT NULL;

-- ── Redirect back to review ────────────────────────────────────────────────

SELECT 'redirect' AS component,
       'review.sql?id=' || $id AS link;
