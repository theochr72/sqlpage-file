-- index.sql — Dashboard factures

SELECT 'shell' AS component,
       'Invoice Manager' AS title,
       'file-invoice' AS icon,
       'Dashboard' AS menu_item,
       '/' AS link,
       'Invoices' AS menu_item,
       '/invoices.sql' AS link;

-- ── Big Numbers ──────────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 4 AS columns;

SELECT 'Total Invoices' AS title,
       COUNT(*)::TEXT AS value,
       'file-invoice' AS icon
  FROM accounting.invoice;

SELECT 'This Month' AS title,
       COUNT(*)::TEXT AS value,
       'calendar' AS icon
  FROM accounting.invoice
 WHERE issue_date >= date_trunc('month', CURRENT_DATE);

SELECT 'Avg Confidence' AS title,
       COALESCE(ROUND(AVG(overall_confidence) * 100)::TEXT || '%', 'N/A') AS value,
       'target' AS icon,
       CASE WHEN AVG(overall_confidence) >= 0.8 THEN 'green'
            WHEN AVG(overall_confidence) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice;

SELECT 'Low Confidence' AS title,
       COUNT(*)::TEXT AS value,
       'alert-triangle' AS icon,
       'orange' AS color
  FROM accounting.invoice
 WHERE overall_confidence < 0.5;

-- ── Chart: Factures par mois ─────────────────────────────────────────────────

SELECT 'chart' AS component,
       'Invoices by Month' AS title,
       'bar' AS type;

SELECT to_char(issue_date, 'YYYY-MM') AS x,
       COUNT(*) AS y
  FROM accounting.invoice
 WHERE issue_date IS NOT NULL
 GROUP BY to_char(issue_date, 'YYYY-MM')
 ORDER BY x DESC
 LIMIT 12;

-- ── Chart: Top 10 fournisseurs ───────────────────────────────────────────────

SELECT 'chart' AS component,
       'Top 10 Suppliers by Spend' AS title,
       'bar' AS type,
       TRUE AS horizontal;

SELECT supplier_name AS x,
       SUM(total_amount)::REAL AS y
  FROM accounting.invoice
 WHERE supplier_name IS NOT NULL AND total_amount IS NOT NULL
 GROUP BY supplier_name
 ORDER BY y DESC
 LIMIT 10;

-- ── Dernières factures ───────────────────────────────────────────────────────

SELECT 'table' AS component,
       'Recent Invoices' AS title,
       TRUE AS sort,
       'Confidence' AS align_right,
       'Amount' AS align_right;

SELECT invoice_number AS "Invoice #",
       supplier_name AS "Supplier",
       issue_date::TEXT AS "Date",
       COALESCE(total_amount::TEXT || ' ' || COALESCE(currency, ''), '') AS "Amount",
       COALESCE(ROUND(overall_confidence * 100)::TEXT || '%', 'N/A') AS "Confidence",
       status AS "Status",
       'invoice.sql?id=' || id AS _sqlpage_id
  FROM accounting.invoice
 ORDER BY processed_at DESC
 LIMIT 10;
