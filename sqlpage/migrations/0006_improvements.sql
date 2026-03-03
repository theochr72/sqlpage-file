-- 0006_improvements.sql — PDF availability, TVA fields, supplier auto-mapping

-- ── pdf_available on invoice ────────────────────────────────────────────────
ALTER TABLE accounting.invoice ADD COLUMN IF NOT EXISTS pdf_available BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill: mark as available if a renamed file exists
UPDATE accounting.invoice SET pdf_available = TRUE WHERE renamed_filename IS NOT NULL;

-- ── TVA fields on invoice ───────────────────────────────────────────────────
ALTER TABLE accounting.invoice ADD COLUMN IF NOT EXISTS total_ht NUMERIC;
ALTER TABLE accounting.invoice ADD COLUMN IF NOT EXISTS tva_amount NUMERIC;

-- ── TVA rate on invoice_item ────────────────────────────────────────────────
ALTER TABLE accounting.invoice_item ADD COLUMN IF NOT EXISTS tva_rate NUMERIC;

-- ── Supplier → category/property auto-mapping ───────────────────────────────
CREATE TABLE IF NOT EXISTS accounting.supplier_mapping (
    id            SERIAL PRIMARY KEY,
    supplier_pattern TEXT NOT NULL,
    category_code TEXT REFERENCES accounting.expense_category(code),
    property_id   INT  REFERENCES accounting.property(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (supplier_pattern)
);
