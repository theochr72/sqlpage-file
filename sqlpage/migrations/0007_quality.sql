-- 0007_quality.sql — Indexes, constraints, audit log, invoice summary view

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. Missing indexes
-- ══════════════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_invoice_property_fiscal
    ON accounting.invoice (property_id, fiscal_year);

CREATE INDEX IF NOT EXISTS idx_invoice_status_confidence
    ON accounting.invoice (status, overall_confidence);

CREATE INDEX IF NOT EXISTS idx_lease_property_dates
    ON accounting.lease (property_id, end_date);

CREATE INDEX IF NOT EXISTS idx_rent_payment_lease_period
    ON accounting.rent_payment (lease_id, period_year, period_month);

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. CHECK constraints
-- ══════════════════════════════════════════════════════════════════════════════

-- Positive amounts
ALTER TABLE accounting.invoice
    ADD CONSTRAINT chk_invoice_total_positive CHECK (total_amount IS NULL OR total_amount >= 0);

ALTER TABLE accounting.invoice
    ADD CONSTRAINT chk_invoice_ht_positive CHECK (total_ht IS NULL OR total_ht >= 0);

ALTER TABLE accounting.lease
    ADD CONSTRAINT chk_lease_rent_positive CHECK (monthly_rent > 0);

ALTER TABLE accounting.lease
    ADD CONSTRAINT chk_lease_charges_positive CHECK (charges >= 0);

ALTER TABLE accounting.rent_payment
    ADD CONSTRAINT chk_rent_amount_positive CHECK (amount > 0);

-- Date ordering
ALTER TABLE accounting.lease
    ADD CONSTRAINT chk_lease_dates CHECK (end_date IS NULL OR end_date >= start_date);

ALTER TABLE accounting.invoice
    ADD CONSTRAINT chk_invoice_dates CHECK (due_date IS NULL OR issue_date IS NULL OR due_date >= issue_date);

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. Audit log table
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS accounting.audit_log (
    id          SERIAL PRIMARY KEY,
    table_name  TEXT NOT NULL,
    record_id   INT NOT NULL,
    action      TEXT NOT NULL,              -- 'status_change', 'manual_edit', 'extraction', 'bulk_action'
    old_values  JSONB,
    new_values  JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_record
    ON accounting.audit_log (table_name, record_id, created_at DESC);

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. Invoice summary view (DRY: used across multiple pages)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW accounting.vw_invoice_summary AS
SELECT i.id,
       i.invoice_number,
       i.document_type,
       i.issue_date,
       i.due_date,
       i.supplier_name,
       i.supplier_vat_id,
       i.total_amount,
       i.total_ht,
       i.tva_amount,
       i.currency,
       i.status,
       i.overall_confidence,
       i.property_id,
       i.category_code,
       i.fiscal_year,
       i.notes,
       i.pdf_available,
       i.manually_edited_at,
       i.manually_edited_fields,
       i.processed_at,
       i.original_filename,
       i.renamed_filename,
       -- Joined fields
       COALESCE(c.label, 'Uncategorized') AS category_label,
       COALESCE(c.deductible, FALSE) AS category_deductible,
       COALESCE(p.name, 'Unassigned') AS property_name,
       p.city AS property_city,
       -- Computed display fields
       CASE WHEN i.status = 'pending_review' THEN 'Pending'
            WHEN i.status = 'validated' THEN 'Validated'
            WHEN i.status = 'rejected' THEN 'Rejected'
       END AS status_label,
       CASE WHEN i.status = 'validated' THEN 'green'
            WHEN i.status = 'rejected' THEN 'red'
            ELSE 'orange' END AS status_color,
       CASE WHEN i.status = 'validated' THEN 'circle-check'
            WHEN i.status = 'rejected' THEN 'circle-x'
            ELSE 'clock' END AS status_icon,
       -- Confidence color
       CASE WHEN i.overall_confidence >= 0.8 THEN 'green'
            WHEN i.overall_confidence >= 0.5 THEN 'orange'
            ELSE 'red' END AS confidence_color,
       -- Item count
       (SELECT COUNT(*) FROM accounting.invoice_item it
         WHERE it.invoice_number = i.invoice_number) AS item_count
  FROM accounting.invoice i
  LEFT JOIN accounting.expense_category c ON c.code = i.category_code
  LEFT JOIN accounting.property p ON p.id = i.property_id;
