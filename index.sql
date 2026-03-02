-- index.sql — Dashboard

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── Alertes actionnables ───────────────────────────────────────────────────

SELECT 'alert' AS component,
       'upload' AS icon,
       'azure' AS color,
       COUNT(*)::TEXT || ' file(s) awaiting processing' AS title,
       'Run invoice_insert.py to extract data.' AS description,
       '/upload.sql' AS link,
       'Upload' AS link_text,
       TRUE AS dismissible
  FROM accounting.pending_upload
 WHERE processed = FALSE
HAVING COUNT(*) > 0;

SELECT 'alert' AS component,
       'alert-triangle' AS icon,
       'orange' AS color,
       COUNT(*)::TEXT || ' invoice(s) with low confidence (< 50%)' AS title,
       'These need manual review before validation.' AS description,
       'invoices.sql?status=pending_review' AS link,
       'Review now' AS link_text,
       TRUE AS dismissible
  FROM accounting.invoice
 WHERE overall_confidence < 0.5 AND status = 'pending_review'
HAVING COUNT(*) > 0;

-- Late rent alert
SELECT 'alert' AS component,
       'cash-off' AS icon,
       'red' AS color,
       COUNT(*)::TEXT || ' late rent payment(s) this month' AS title,
       'Record payments to clear this alert.' AS description,
       'rent.sql' AS link,
       'View rent' AS link_text,
       TRUE AS dismissible
  FROM accounting.lease l
 WHERE l.start_date <= CURRENT_DATE
   AND (l.end_date IS NULL OR l.end_date >= date_trunc('month', CURRENT_DATE)::DATE)
   AND NOT EXISTS (
       SELECT 1 FROM accounting.rent_payment rp
        WHERE rp.lease_id = l.id
          AND rp.period_year = EXTRACT(YEAR FROM CURRENT_DATE)::INT
          AND rp.period_month = EXTRACT(MONTH FROM CURRENT_DATE)::INT
   )
HAVING COUNT(*) > 0;

-- ── KPIs ───────────────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 4 AS columns;

SELECT 'Pending Review' AS title,
       COUNT(*)::TEXT AS value,
       'clock' AS icon,
       CASE WHEN COUNT(*) > 0 THEN 'orange' ELSE 'green' END AS color,
       'invoices.sql?status=pending_review' AS value_link
  FROM accounting.invoice WHERE status = 'pending_review';

SELECT 'Validated' AS title,
       COUNT(*)::TEXT AS value,
       'circle-check' AS icon,
       'green' AS color,
       CASE WHEN (SELECT COUNT(*) FROM accounting.invoice) > 0
            THEN ROUND(COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM accounting.invoice) * 100)::INT
       END AS progress_percent,
       'green' AS progress_color
  FROM accounting.invoice WHERE status = 'validated';

SELECT 'Total Spend' AS title,
       COALESCE(to_char(SUM(total_amount), 'FM999G999D00') || ' €', '0 €') AS value,
       'currency-euro' AS icon,
       'cyan' AS color
  FROM accounting.invoice
 WHERE status = 'validated';

-- Monthly cash-flow KPI
SELECT 'Cash-Flow (month)' AS title,
       to_char(
           COALESCE((SELECT SUM(rp.amount)
                       FROM accounting.rent_payment rp
                       JOIN accounting.lease l ON l.id = rp.lease_id
                      WHERE rp.period_year = EXTRACT(YEAR FROM CURRENT_DATE)::INT
                        AND rp.period_month = EXTRACT(MONTH FROM CURRENT_DATE)::INT), 0)
           - COALESCE((SELECT SUM(i.total_amount)
                         FROM accounting.invoice i
                        WHERE EXTRACT(MONTH FROM i.issue_date) = EXTRACT(MONTH FROM CURRENT_DATE)
                          AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = EXTRACT(YEAR FROM CURRENT_DATE)::INT
                          AND i.status = 'validated'), 0),
       'FM999G999D00') || ' €' AS value,
       'scale' AS icon,
       CASE WHEN COALESCE((SELECT SUM(rp.amount)
                              FROM accounting.rent_payment rp
                              JOIN accounting.lease l ON l.id = rp.lease_id
                             WHERE rp.period_year = EXTRACT(YEAR FROM CURRENT_DATE)::INT
                               AND rp.period_month = EXTRACT(MONTH FROM CURRENT_DATE)::INT), 0)
                - COALESCE((SELECT SUM(i.total_amount)
                              FROM accounting.invoice i
                             WHERE EXTRACT(MONTH FROM i.issue_date) = EXTRACT(MONTH FROM CURRENT_DATE)
                               AND COALESCE(i.fiscal_year, EXTRACT(YEAR FROM i.issue_date)::INT) = EXTRACT(YEAR FROM CURRENT_DATE)::INT
                               AND i.status = 'validated'), 0)
                >= 0 THEN 'green' ELSE 'red' END AS color,
       'monthly.sql' AS value_link;

-- ── Chart: Dépenses mensuelles ─────────────────────────────────────────────

SELECT 'chart' AS component,
       'Monthly Spending' AS title,
       'area' AS type,
       TRUE AS toolbar,
       0 AS ymin,
       350 AS height;

SELECT to_char(d.month, 'YYYY-MM') AS x,
       COALESCE(ROUND(SUM(i.total_amount)::NUMERIC, 2), 0) AS y,
       'Spend (€)' AS series
  FROM generate_series(
           date_trunc('month', CURRENT_DATE) - INTERVAL '11 months',
           date_trunc('month', CURRENT_DATE),
           '1 month'
       ) AS d(month)
  LEFT JOIN accounting.invoice i
    ON date_trunc('month', i.issue_date) = d.month
   AND i.total_amount IS NOT NULL
 GROUP BY d.month
 ORDER BY d.month;

-- ── Factures en attente de review ──────────────────────────────────────────

SELECT 'title' AS component,
       'Pending Review' AS contents,
       3 AS level;

-- Empty state
SELECT 'alert' AS component,
       'circle-check' AS icon,
       'green' AS color,
       'All clear' AS title,
       'No invoices pending review.' AS description
 WHERE NOT EXISTS (SELECT 1 FROM accounting.invoice WHERE status = 'pending_review');

SELECT 'card' AS component, 4 AS columns;

SELECT COALESCE(i.supplier_name, 'Unknown') AS title,
       COALESCE(i.total_amount::TEXT || ' ' || COALESCE(i.currency, '€'), 'N/A')
           || ' — ' || COALESCE(i.invoice_number, '?') AS description,
       'review.sql?id=' || i.id AS link,
       CASE WHEN i.overall_confidence >= 0.8 THEN 'green'
            WHEN i.overall_confidence >= 0.5 THEN 'orange'
            ELSE 'red' END AS color,
       COALESCE(ROUND(i.overall_confidence * 100)::TEXT || '% conf.', '') AS footer,
       COALESCE(i.issue_date::TEXT, '') AS footer_md
  FROM accounting.invoice i
 WHERE i.status = 'pending_review'
 ORDER BY i.overall_confidence ASC NULLS FIRST, i.processed_at DESC
 LIMIT 8;

-- Link to all pending if more than 8
SELECT 'button' AS component, 'center' AS justify, 'sm' AS size;

SELECT 'View all ' || COUNT(*) || ' pending' AS title,
       'invoices.sql?status=pending_review' AS link,
       'arrow-right' AS icon_after,
       'orange' AS outline
  FROM accounting.invoice
 WHERE status = 'pending_review'
HAVING COUNT(*) > 8;

-- ── Activité récente ───────────────────────────────────────────────────────

SELECT 'title' AS component,
       'Recent Activity' AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS hover,
       TRUE AS striped_rows,
       'Amount,Confidence' AS align_right,
       'No invoices yet.' AS empty_description;

SELECT invoice_number AS "Invoice",
       supplier_name AS "Supplier",
       issue_date::TEXT AS "Date",
       COALESCE(total_amount::TEXT || ' ' || COALESCE(currency, '€'), '') AS "Amount",
       COALESCE(ROUND(overall_confidence * 100)::TEXT || '%', '-') AS "Confidence",
       CASE WHEN status = 'pending_review' THEN 'Pending'
            WHEN status = 'validated' THEN 'Validated'
            WHEN status = 'rejected' THEN 'Rejected'
       END AS "Status",
       CASE WHEN status = 'validated' THEN 'green'
            WHEN status = 'rejected' THEN 'red'
            WHEN overall_confidence < 0.5 THEN 'red'
            WHEN overall_confidence < 0.8 THEN 'yellow'
       END AS _sqlpage_color,
       'invoice.sql?id=' || id AS _sqlpage_id
  FROM accounting.invoice
 ORDER BY processed_at DESC
 LIMIT 10;
