-- 0003_manual_edits.sql — Track manual edits and enable duplicate detection

ALTER TABLE accounting.invoice
    ADD COLUMN IF NOT EXISTS manually_edited_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS manually_edited_fields TEXT[];

CREATE INDEX IF NOT EXISTS idx_invoice_original_filename
    ON accounting.invoice(original_filename);

CREATE INDEX IF NOT EXISTS idx_invoice_renamed_filename
    ON accounting.invoice(renamed_filename);
