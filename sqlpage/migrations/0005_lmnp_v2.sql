-- 0005_lmnp_v2.sql — Extension LMNP : locataires, baux, loyers, dépenses récurrentes

-- Property enhancement
ALTER TABLE accounting.property
    ADD COLUMN IF NOT EXISTS purchase_price      NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS purchase_date       DATE,
    ADD COLUMN IF NOT EXISTS mortgage_monthly    NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS mortgage_start_date DATE,
    ADD COLUMN IF NOT EXISTS mortgage_end_date   DATE,
    ADD COLUMN IF NOT EXISTS surface_area        NUMERIC(8,2);

-- Tenants
CREATE TABLE IF NOT EXISTS accounting.tenant (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    email      TEXT,
    phone      TEXT,
    notes      TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Leases (end_date NULL = actif)
CREATE TABLE IF NOT EXISTS accounting.lease (
    id            SERIAL PRIMARY KEY,
    tenant_id     INTEGER NOT NULL REFERENCES accounting.tenant(id) ON DELETE CASCADE,
    property_id   INTEGER NOT NULL REFERENCES accounting.property(id) ON DELETE CASCADE,
    start_date    DATE NOT NULL,
    end_date      DATE,
    monthly_rent  NUMERIC(12,2) NOT NULL,
    charges       NUMERIC(12,2) NOT NULL DEFAULT 0,
    deposit       NUMERIC(12,2),
    revision_date DATE,
    notes         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lease_property ON accounting.lease(property_id);
CREATE INDEX IF NOT EXISTS idx_lease_tenant   ON accounting.lease(tenant_id);
CREATE INDEX IF NOT EXISTS idx_lease_dates    ON accounting.lease(start_date, end_date);

-- Rent payments (1 par bail par mois)
CREATE TABLE IF NOT EXISTS accounting.rent_payment (
    id             SERIAL PRIMARY KEY,
    lease_id       INTEGER NOT NULL REFERENCES accounting.lease(id) ON DELETE CASCADE,
    payment_date   DATE NOT NULL,
    amount         NUMERIC(12,2) NOT NULL,
    period_month   INTEGER NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    period_year    INTEGER NOT NULL,
    payment_method TEXT DEFAULT 'transfer' CHECK (payment_method IN ('transfer','check','cash','other')),
    notes          TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (lease_id, period_year, period_month)
);
CREATE INDEX IF NOT EXISTS idx_rent_payment_period ON accounting.rent_payment(period_year, period_month);

-- Recurring expense templates
CREATE TABLE IF NOT EXISTS accounting.recurring_expense (
    id            SERIAL PRIMARY KEY,
    property_id   INTEGER NOT NULL REFERENCES accounting.property(id) ON DELETE CASCADE,
    category_code TEXT REFERENCES accounting.expense_category(code),
    supplier_name TEXT,
    description   TEXT NOT NULL,
    amount        NUMERIC(12,2) NOT NULL,
    frequency     TEXT NOT NULL DEFAULT 'monthly' CHECK (frequency IN ('monthly','quarterly','yearly')),
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Track generated invoices from recurring templates
CREATE TABLE IF NOT EXISTS accounting.recurring_expense_generation (
    id                   SERIAL PRIMARY KEY,
    recurring_expense_id INTEGER NOT NULL REFERENCES accounting.recurring_expense(id) ON DELETE CASCADE,
    period_year          INTEGER NOT NULL,
    period_month         INTEGER NOT NULL,
    invoice_id           INTEGER REFERENCES accounting.invoice(id) ON DELETE SET NULL,
    generated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (recurring_expense_id, period_year, period_month)
);
