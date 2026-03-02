-- index.sql — Dashboard

SELECT 'shell' AS component,
       'InvoiceAI' AS title,
       'file-invoice' AS icon,
       TRUE AS sidebar,
       'Dashboard' AS menu_item, '/' AS link,
       'Invoices' AS menu_item, '/invoices.sql' AS link,
       'Fiscal' AS menu_item, '/fiscal.sql' AS link,
       'Properties' AS menu_item, '/properties.sql' AS link,
       'Upload' AS menu_item, '/upload.sql' AS link,
       'dark' AS theme,
       'Inter' AS font;

-- ── Hero ─────────────────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Invoice Dashboard' AS title,
       'AI-powered invoice extraction and management. Upload, extract, review, validate.' AS description;

-- ── Alert: fichiers en attente de traitement ─────────────────────────────────

SELECT 'alert' AS component,
       'upload' AS icon,
       'azure' AS color,
       COUNT(*)::TEXT || ' file(s) awaiting processing' AS title,
       'Run invoice_insert.py on the uploads/ folder to extract data.' AS description,
       '/upload.sql' AS link,
       'Upload more' AS link_text,
       TRUE AS dismissible
  FROM accounting.pending_upload
 WHERE processed = FALSE
HAVING COUNT(*) > 0;

-- ── Alert: factures basse confiance ──────────────────────────────────────────

SELECT 'alert' AS component,
       'alert-triangle' AS icon,
       'orange' AS color,
       COUNT(*)::TEXT || ' invoice(s) with low confidence (< 50%)' AS title,
       'These invoices may contain extraction errors and need manual review.' AS description,
       'invoices.sql?status=pending_review' AS link,
       'Review now' AS link_text,
       TRUE AS dismissible
  FROM accounting.invoice
 WHERE overall_confidence < 0.5 AND status = 'pending_review'
HAVING COUNT(*) > 0;

-- ── KPIs principaux ──────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 4 AS columns;

SELECT 'Total Invoices' AS title,
       COUNT(*)::TEXT AS value,
       'file-invoice' AS icon,
       'azure' AS color
  FROM accounting.invoice;

SELECT 'Total Spend' AS title,
       COALESCE(to_char(SUM(total_amount), 'FM999G999G999D00'), '0') AS value,
       'currency-euro' AS icon,
       'green' AS color
  FROM accounting.invoice;

SELECT 'This Month' AS title,
       COUNT(*)::TEXT AS value,
       'calendar-month' AS icon,
       CASE WHEN COUNT(*) > 0 THEN 'cyan' ELSE 'secondary' END AS color,
       CASE WHEN (
           SELECT COUNT(*) FROM accounting.invoice
            WHERE issue_date >= date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
              AND issue_date < date_trunc('month', CURRENT_DATE)
       ) > 0 THEN
           ROUND(
               (COUNT(*)::NUMERIC /
                NULLIF((SELECT COUNT(*) FROM accounting.invoice
                         WHERE issue_date >= date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
                           AND issue_date < date_trunc('month', CURRENT_DATE)), 0)
                - 1) * 100
           )::INT
       END AS change_percent
  FROM accounting.invoice
 WHERE issue_date >= date_trunc('month', CURRENT_DATE);

SELECT 'Avg Confidence' AS title,
       COALESCE(ROUND(AVG(overall_confidence) * 100)::TEXT || '%', '-') AS value,
       'target' AS icon,
       CASE WHEN COALESCE(AVG(overall_confidence), 0) >= 0.8 THEN 'green'
            WHEN COALESCE(AVG(overall_confidence), 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color,
       ROUND(COALESCE(AVG(overall_confidence), 0) * 100)::INT AS progress_percent,
       CASE WHEN COALESCE(AVG(overall_confidence), 0) >= 0.8 THEN 'green'
            WHEN COALESCE(AVG(overall_confidence), 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS progress_color
  FROM accounting.invoice;

-- ── Statut breakdown ─────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 3 AS columns;

SELECT 'Pending Review' AS title,
       COUNT(*)::TEXT AS value,
       'clock' AS icon,
       'orange' AS color,
       CASE WHEN (SELECT COUNT(*) FROM accounting.invoice) > 0
            THEN ROUND(COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM accounting.invoice) * 100)::INT
       END AS progress_percent,
       'orange' AS progress_color
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

SELECT 'Rejected' AS title,
       COUNT(*)::TEXT AS value,
       'circle-x' AS icon,
       'red' AS color,
       CASE WHEN (SELECT COUNT(*) FROM accounting.invoice) > 0
            THEN ROUND(COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM accounting.invoice) * 100)::INT
       END AS progress_percent,
       'red' AS progress_color
  FROM accounting.invoice WHERE status = 'rejected';

-- ── Chart: Tendance mensuelle (area) ─────────────────────────────────────────

SELECT 'chart' AS component,
       'Monthly Spending Trend' AS title,
       'area' AS type,
       TRUE AS toolbar,
       TRUE AS labels,
       0 AS ymin,
       400 AS height;

SELECT to_char(issue_date, 'YYYY-MM') AS x,
       ROUND(SUM(total_amount)::NUMERIC, 2) AS y,
       'Spend' AS series
  FROM accounting.invoice
 WHERE issue_date IS NOT NULL AND total_amount IS NOT NULL
 GROUP BY to_char(issue_date, 'YYYY-MM')
 ORDER BY x
 LIMIT 12;

-- ── Chart: Status distribution (pie) ─────────────────────────────────────────

SELECT 'chart' AS component,
       'Status Distribution' AS title,
       'pie' AS type,
       TRUE AS labels,
       300 AS height;

SELECT status AS label,
       COUNT(*) AS value,
       status AS x,
       COUNT(*) AS y
  FROM accounting.invoice
 GROUP BY status;

-- ── Chart: Confidence distribution (pie) ─────────────────────────────────────

SELECT 'chart' AS component,
       'Confidence Distribution' AS title,
       'pie' AS type,
       TRUE AS labels,
       300 AS height;

SELECT label AS x, cnt AS y FROM (
    SELECT 'High (>80%)' AS label, COUNT(*) AS cnt, 1 AS ord
      FROM accounting.invoice WHERE overall_confidence >= 0.8
    UNION ALL
    SELECT 'Medium (50-80%)', COUNT(*), 2
      FROM accounting.invoice WHERE overall_confidence >= 0.5 AND overall_confidence < 0.8
    UNION ALL
    SELECT 'Low (<50%)', COUNT(*), 3
      FROM accounting.invoice WHERE overall_confidence < 0.5
) sub
WHERE cnt > 0
ORDER BY ord;

-- ── Chart: Top fournisseurs ──────────────────────────────────────────────────

SELECT 'chart' AS component,
       'Top 10 Suppliers by Spend' AS title,
       'bar' AS type,
       TRUE AS horizontal,
       TRUE AS labels,
       TRUE AS toolbar,
       400 AS height;

SELECT supplier_name AS x,
       ROUND(SUM(total_amount)::NUMERIC, 2) AS y
  FROM accounting.invoice
 WHERE supplier_name IS NOT NULL AND total_amount IS NOT NULL
 GROUP BY supplier_name
 ORDER BY y DESC
 LIMIT 10;

-- ── Chart: Volume mensuel de factures (bar) ──────────────────────────────────

SELECT 'chart' AS component,
       'Monthly Invoice Count' AS title,
       'bar' AS type,
       TRUE AS labels,
       300 AS height;

SELECT to_char(issue_date, 'YYYY-MM') AS x,
       COUNT(*) AS y,
       'Invoices' AS series
  FROM accounting.invoice
 WHERE issue_date IS NOT NULL
 GROUP BY to_char(issue_date, 'YYYY-MM')
 ORDER BY x
 LIMIT 12;

-- ── Factures en attente de review ────────────────────────────────────────────

SELECT 'title' AS component,
       'Pending Review' AS contents,
       3 AS level;

SELECT 'card' AS component, 4 AS columns;

SELECT COALESCE(i.invoice_number, '?') || ' — ' || COALESCE(i.supplier_name, '?') AS title,
       COALESCE(i.total_amount::TEXT || ' ' || COALESCE(i.currency, ''), 'N/A') AS description,
       COALESCE(i.issue_date::TEXT, '') AS footer,
       'invoice.sql?id=' || i.id AS link,
       CASE WHEN i.overall_confidence >= 0.8 THEN 'green'
            WHEN i.overall_confidence >= 0.5 THEN 'orange'
            ELSE 'red' END AS color,
       COALESCE(ROUND(i.overall_confidence * 100)::TEXT || '% confidence', '') AS footer_md
  FROM accounting.invoice i
 WHERE i.status = 'pending_review'
 ORDER BY i.overall_confidence ASC NULLS FIRST, i.processed_at DESC
 LIMIT 8;

-- ── Dernières factures traitées ──────────────────────────────────────────────

SELECT 'title' AS component,
       'Recent Activity' AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS hover,
       TRUE AS striped_rows,
       'Confidence' AS align_right,
       'Amount' AS align_right,
       'No invoices yet. Upload some PDFs to get started!' AS empty_description;

SELECT invoice_number AS "Invoice #",
       supplier_name AS "Supplier",
       issue_date::TEXT AS "Date",
       COALESCE(total_amount::TEXT || ' ' || COALESCE(currency, ''), '') AS "Amount",
       COALESCE(ROUND(overall_confidence * 100)::TEXT || '%', '-') AS "Confidence",
       status AS "Status",
       CASE WHEN status = 'validated' THEN 'green'
            WHEN status = 'rejected' THEN 'red'
            WHEN overall_confidence < 0.5 THEN 'red'
            WHEN overall_confidence < 0.8 THEN 'yellow'
            ELSE NULL END AS _sqlpage_color,
       'invoice.sql?id=' || id AS _sqlpage_id
  FROM accounting.invoice
 ORDER BY processed_at DESC
 LIMIT 15;
