-- save_rent.sql — Save a rent payment

INSERT INTO accounting.rent_payment (lease_id, payment_date, amount, period_month, period_year, payment_method, notes)
SELECT $lease_id::INT,
       $payment_date::DATE,
       $amount::NUMERIC,
       $period_month::INT,
       $period_year::INT,
       COALESCE(NULLIF($payment_method, ''), 'transfer'),
       NULLIF($notes, '')
 WHERE $lease_id IS NOT NULL AND $lease_id != ''
   AND $amount IS NOT NULL AND $amount != ''
ON CONFLICT (lease_id, period_year, period_month) DO UPDATE
   SET payment_date   = EXCLUDED.payment_date,
       amount         = EXCLUDED.amount,
       payment_method = EXCLUDED.payment_method,
       notes          = EXCLUDED.notes;

SELECT 'redirect' AS component,
       'rent.sql?year=' || $period_year AS link;
