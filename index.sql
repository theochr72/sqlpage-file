-- index.sql — Tableau de bord

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── Hero d'accueil ──────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Bienvenue sur Mon LMNP' AS title,
       'Votre assistant de gestion locative. Suivez vos loyers, vos depenses et la rentabilite de vos biens en un coup d''oeil.' AS description;

SELECT 'Mes biens' AS title,
       'Gerer vos proprietes' AS description,
       'building' AS icon,
       '/properties.sql' AS link;

SELECT 'Enregistrer un loyer' AS title,
       'Saisir un paiement recu' AS description,
       'cash' AS icon,
       '/rent_form.sql' AS link;

SELECT 'Bilan du mois' AS title,
       'Voir le resume mensuel' AS description,
       'calendar-month' AS icon,
       '/monthly.sql' AS link;

-- ── Alertes actionnables ───────────────────────────────────────────────────

SELECT 'alert' AS component,
       'upload' AS icon,
       'azure' AS color,
       COUNT(*)::TEXT || ' fichier(s) en attente de traitement' AS title,
       'Lancez invoice_insert.py pour extraire les donnees automatiquement.' AS description,
       '/upload.sql' AS link,
       'Voir les imports' AS link_text,
       TRUE AS dismissible
  FROM accounting.pending_upload
 WHERE processed = FALSE
HAVING COUNT(*) > 0;

SELECT 'alert' AS component,
       'alert-triangle' AS icon,
       'orange' AS color,
       COUNT(*)::TEXT || ' facture(s) avec une confiance faible (< 50%)' AS title,
       'Ces factures necessitent une verification manuelle avant validation.' AS description,
       'invoices.sql?status=pending_review' AS link,
       'Verifier maintenant' AS link_text,
       TRUE AS dismissible
  FROM accounting.invoice
 WHERE overall_confidence < 0.5 AND status = 'pending_review'
HAVING COUNT(*) > 0;

-- Alerte loyers en retard
SELECT 'alert' AS component,
       'cash-off' AS icon,
       'red' AS color,
       COUNT(*)::TEXT || ' loyer(s) en retard ce mois-ci' AS title,
       'Des paiements sont attendus mais n''ont pas encore ete enregistres. Pensez a les saisir.' AS description,
       'rent.sql' AS link,
       'Voir les loyers' AS link_text,
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

-- ── KPIs principaux ─────────────────────────────────────────────────────────

SELECT 'big_number' AS component, 4 AS columns;

SELECT 'A verifier' AS title,
       COUNT(*)::TEXT AS value,
       'Factures en attente de review' AS description,
       'clock' AS icon,
       CASE WHEN COUNT(*) > 0 THEN 'orange' ELSE 'green' END AS color,
       'invoices.sql?status=pending_review' AS value_link
  FROM accounting.invoice WHERE status = 'pending_review';

SELECT 'Validees' AS title,
       COUNT(*)::TEXT AS value,
       'Factures traitees et confirmees' AS description,
       'circle-check' AS icon,
       'green' AS color,
       CASE WHEN (SELECT COUNT(*) FROM accounting.invoice) > 0
            THEN ROUND(COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM accounting.invoice) * 100)::INT
       END AS progress_percent,
       'green' AS progress_color
  FROM accounting.invoice WHERE status = 'validated';

SELECT 'Depenses totales' AS title,
       COALESCE(to_char(SUM(total_amount), 'FM999G999D00'), '0') AS value,
       'Montant cumule des factures validees' AS description,
       '€' AS unit,
       'currency-euro' AS icon,
       'cyan' AS color
  FROM accounting.invoice
 WHERE status = 'validated';

-- Cash-flow du mois
SELECT 'Cash-flow du mois' AS title,
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
       'FM999G999D00') AS value,
       'Loyers recus moins depenses' AS description,
       '€' AS unit,
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

-- ── Depenses sur 12 mois ──────────────────────────────────────────────────

SELECT 'divider' AS component, 'Evolution des depenses' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Vue d''ensemble de vos depenses validees sur les 12 derniers mois. Permet de reperer les tendances et les pics de depenses saisonnieres.' AS contents,
       TRUE AS italics;

SELECT 'chart' AS component,
       'Depenses mensuelles' AS title,
       'area' AS type,
       TRUE AS toolbar,
       0 AS ymin,
       350 AS height;

SELECT to_char(d.month, 'YYYY-MM') AS x,
       COALESCE(ROUND(SUM(i.total_amount)::NUMERIC, 2), 0) AS y,
       'Depenses (€)' AS series
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

SELECT 'divider' AS component, 'Factures a verifier' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Ces factures ont ete extraites automatiquement et attendent votre validation. Cliquez sur une carte pour la verifier.' AS contents,
       TRUE AS italics;

-- Empty state
SELECT 'alert' AS component,
       'circle-check' AS icon,
       'green' AS color,
       'Tout est en ordre !' AS title,
       'Aucune facture en attente de verification. Vous etes a jour.' AS description
 WHERE NOT EXISTS (SELECT 1 FROM accounting.invoice WHERE status = 'pending_review');

SELECT 'card' AS component, 4 AS columns;

SELECT COALESCE(i.supplier_name, 'Fournisseur inconnu') AS title,
       COALESCE(i.total_amount::TEXT || ' ' || COALESCE(i.currency, '€'), 'N/A')
           || ' — ' || COALESCE(i.invoice_number, '?') AS description,
       'review.sql?id=' || i.id AS link,
       CASE WHEN i.overall_confidence >= 0.8 THEN 'green'
            WHEN i.overall_confidence >= 0.5 THEN 'orange'
            ELSE 'red' END AS color,
       COALESCE(ROUND(i.overall_confidence * 100)::TEXT || '% de confiance', '') AS footer,
       COALESCE(i.issue_date::TEXT, '') AS footer_md
  FROM accounting.invoice i
 WHERE i.status = 'pending_review'
 ORDER BY i.overall_confidence ASC NULLS FIRST, i.processed_at DESC
 LIMIT 8;

SELECT 'button' AS component, 'center' AS justify, 'sm' AS size;

SELECT 'Voir les ' || COUNT(*) || ' en attente' AS title,
       'invoices.sql?status=pending_review' AS link,
       'arrow-right' AS icon_after,
       'orange' AS outline
  FROM accounting.invoice
 WHERE status = 'pending_review'
HAVING COUNT(*) > 8;

-- ── Activite recente ─────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Activite recente' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Les 10 dernieres factures traitees. Cliquez sur une ligne pour voir le detail.' AS contents,
       TRUE AS italics;

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS hover,
       TRUE AS striped_rows,
       'Montant,Confiance' AS align_right,
       'Aucune facture pour le moment. Importez votre premier document depuis la page Import.' AS empty_description;

SELECT invoice_number AS "N° Facture",
       supplier_name AS "Fournisseur",
       issue_date::TEXT AS "Date",
       COALESCE(total_amount::TEXT || ' ' || COALESCE(currency, '€'), '') AS "Montant",
       COALESCE(ROUND(overall_confidence * 100)::TEXT || '%', '-') AS "Confiance",
       CASE WHEN status = 'pending_review' THEN 'A verifier'
            WHEN status = 'validated' THEN 'Validee'
            WHEN status = 'rejected' THEN 'Rejetee'
       END AS "Statut",
       CASE WHEN status = 'validated' THEN 'green'
            WHEN status = 'rejected' THEN 'red'
            WHEN overall_confidence < 0.5 THEN 'red'
            WHEN overall_confidence < 0.8 THEN 'yellow'
       END AS _sqlpage_color,
       'invoice.sql?id=' || id AS _sqlpage_id
  FROM accounting.invoice
 ORDER BY processed_at DESC
 LIMIT 10;
