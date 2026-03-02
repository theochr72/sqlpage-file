-- 0004_lmnp.sql — Tables et colonnes pour la gestion LMNP

-- Biens immobiliers
CREATE TABLE IF NOT EXISTS accounting.property (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    address     TEXT,
    city        TEXT,
    type        TEXT DEFAULT 'apartment' CHECK (type IN ('apartment', 'house', 'studio', 'parking', 'other')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Catégories de dépenses LMNP
CREATE TABLE IF NOT EXISTS accounting.expense_category (
    id          SERIAL PRIMARY KEY,
    code        TEXT NOT NULL UNIQUE,
    label       TEXT NOT NULL,
    deductible  BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order  INTEGER NOT NULL DEFAULT 0
);

-- Catégories prédéfinies
INSERT INTO accounting.expense_category (code, label, deductible, sort_order) VALUES
    ('travaux',         'Travaux',                      TRUE,  1),
    ('assurance',       'Assurance',                    TRUE,  2),
    ('charges_copro',   'Charges de copropriété',       TRUE,  3),
    ('taxe_fonciere',   'Taxe foncière',                TRUE,  4),
    ('interets',        'Intérêts d''emprunt',          TRUE,  5),
    ('frais_gestion',   'Frais de gestion',             TRUE,  6),
    ('entretien',       'Entretien / réparations',      TRUE,  7),
    ('mobilier',        'Mobilier / équipement',        TRUE,  8),
    ('honoraires',      'Honoraires (comptable, etc.)', TRUE,  9),
    ('eau_energie',     'Eau / énergie',                TRUE, 10),
    ('divers',          'Divers',                       TRUE, 11)
ON CONFLICT (code) DO NOTHING;

-- Colonnes LMNP sur la table invoice
ALTER TABLE accounting.invoice
    ADD COLUMN IF NOT EXISTS property_id      INTEGER REFERENCES accounting.property(id),
    ADD COLUMN IF NOT EXISTS category_code    TEXT REFERENCES accounting.expense_category(code),
    ADD COLUMN IF NOT EXISTS fiscal_year      INTEGER,
    ADD COLUMN IF NOT EXISTS notes            TEXT;

CREATE INDEX IF NOT EXISTS idx_invoice_property   ON accounting.invoice(property_id);
CREATE INDEX IF NOT EXISTS idx_invoice_category   ON accounting.invoice(category_code);
CREATE INDEX IF NOT EXISTS idx_invoice_fiscal_year ON accounting.invoice(fiscal_year);
