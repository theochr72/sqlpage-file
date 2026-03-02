-- 0001_create_accounting_schema.sql

CREATE SCHEMA IF NOT EXISTS accounting;

CREATE TABLE IF NOT EXISTS accounting.invoice (
    id                          SERIAL PRIMARY KEY,
    invoice_number              TEXT NOT NULL UNIQUE CHECK (invoice_number != ''),
    document_type               TEXT,
    issue_date                  DATE,
    due_date                    DATE,
    supplier_name               TEXT,
    supplier_vat_id             TEXT,
    supplier_address            TEXT,
    customer_name               TEXT,
    customer_address            TEXT,
    total_amount                NUMERIC(12,2),
    currency                    TEXT,

    -- Confidence scores (0.0 to 1.0) for each extracted field
    invoice_number_confidence   REAL,
    document_type_confidence    REAL,
    issue_date_confidence       REAL,
    due_date_confidence         REAL,
    supplier_name_confidence    REAL,
    supplier_vat_id_confidence  REAL,
    supplier_address_confidence REAL,
    customer_name_confidence    REAL,
    customer_address_confidence REAL,
    total_amount_confidence     REAL,
    currency_confidence         REAL,

    -- Metadata
    original_filename           TEXT,
    renamed_filename            TEXT,
    raw_json                    JSONB,
    processed_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    overall_confidence          REAL CHECK (overall_confidence IS NULL OR (overall_confidence >= 0 AND overall_confidence <= 1)),
    status                      TEXT NOT NULL DEFAULT 'pending_review'
                                CHECK (status IN ('pending_review', 'validated', 'rejected'))
);

CREATE TABLE IF NOT EXISTS accounting.invoice_item (
    id                      SERIAL PRIMARY KEY,
    invoice_number          TEXT NOT NULL REFERENCES accounting.invoice(invoice_number)
                            ON DELETE CASCADE,
    item_index              INTEGER NOT NULL,
    description             TEXT,
    quantity                NUMERIC(12,4),
    unit_price              NUMERIC(12,4),
    total                   NUMERIC(12,2),

    -- Confidence scores
    description_confidence  REAL,
    quantity_confidence      REAL,
    unit_price_confidence   REAL,
    total_confidence        REAL,

    UNIQUE (invoice_number, item_index)
);

CREATE INDEX IF NOT EXISTS idx_invoice_status     ON accounting.invoice(status);
CREATE INDEX IF NOT EXISTS idx_invoice_issue_date ON accounting.invoice(issue_date);
CREATE INDEX IF NOT EXISTS idx_invoice_supplier   ON accounting.invoice(supplier_name);
