-- generate_recurring.sql — Generate an invoice from a recurring expense template

SELECT 'redirect' AS component, 'recurring.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

-- Current period
SET _cur_month = EXTRACT(MONTH FROM CURRENT_DATE)::TEXT;
SET _cur_year  = EXTRACT(YEAR FROM CURRENT_DATE)::TEXT;

-- Guard: already generated
SELECT 'redirect' AS component, 'recurring.sql' AS link
 WHERE EXISTS (
     SELECT 1 FROM accounting.recurring_expense_generation
      WHERE recurring_expense_id = $id::INT
        AND period_year = $_cur_year::INT
        AND period_month = $_cur_month::INT
 );

-- Create invoice
SET _invoice_id = (
    INSERT INTO accounting.invoice (
        invoice_number, supplier_name, issue_date, total_amount, currency,
        status, property_id, category_code, fiscal_year, notes
    )
    SELECT 'REC-' || re.id || '-' || $_cur_year || '-' || LPAD($_cur_month, 2, '0'),
           COALESCE(re.supplier_name, re.description),
           CURRENT_DATE,
           re.amount,
           'EUR',
           'validated',
           re.property_id,
           re.category_code,
           $_cur_year::INT,
           'Generee automatiquement depuis le modele recurrent #' || re.id
      FROM accounting.recurring_expense re
     WHERE re.id = $id::INT AND re.active = TRUE
    RETURNING id
);

-- Track generation
INSERT INTO accounting.recurring_expense_generation (recurring_expense_id, period_year, period_month, invoice_id)
SELECT $id::INT, $_cur_year::INT, $_cur_month::INT, $_invoice_id::INT
 WHERE $_invoice_id IS NOT NULL;

SELECT 'redirect' AS component, 'recurring.sql' AS link;
