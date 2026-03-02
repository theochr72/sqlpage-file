-- lease.sql — Fiche detaillee d'un bail

SELECT 'redirect' AS component, 'leases.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'breadcrumb' AS component;
SELECT 'Tableau de bord' AS title, '/' AS link;
SELECT 'Baux' AS title, '/leases.sql' AS link;
SELECT t.name || ' — ' || p.name AS title, TRUE AS active
  FROM accounting.lease l
  JOIN accounting.tenant t ON t.id = l.tenant_id
  JOIN accounting.property p ON p.id = l.property_id
 WHERE l.id = $id::INT;

-- ── Statut du bail ──────────────────────────────────────────────────────────

SELECT 'alert' AS component,
       CASE WHEN l.end_date IS NULL
            THEN 'Ce bail est actuellement en cours.'
            ELSE 'Ce bail est termine depuis le ' || l.end_date::TEXT || '.' END AS title,
       CASE WHEN l.end_date IS NULL THEN 'circle-check' ELSE 'circle-x' END AS icon,
       CASE WHEN l.end_date IS NULL THEN 'green' ELSE NULL END AS color,
       CASE WHEN l.end_date IS NULL
            THEN 'Le locataire est en place. Vous pouvez enregistrer les loyers et suivre les paiements.'
            ELSE 'Ce bail fait partie de l''historique. Aucun loyer ne peut etre enregistre.' END AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

-- ── Informations du bail ────────────────────────────────────────────────────

SELECT 'datagrid' AS component,
       'Detail du bail' AS title,
       'Toutes les conditions financieres et contractuelles.' AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Locataire' AS title, t.name AS description,
       'tenant.sql?id=' || t.id AS link, 'user' AS icon
  FROM accounting.lease l JOIN accounting.tenant t ON t.id = l.tenant_id
 WHERE l.id = $id::INT;

SELECT 'Bien' AS title, p.name AS description,
       'property.sql?id=' || p.id AS link, 'building' AS icon
  FROM accounting.lease l JOIN accounting.property p ON p.id = l.property_id
 WHERE l.id = $id::INT;

SELECT 'Date de debut' AS title, l.start_date::TEXT AS description, 'calendar-event' AS icon
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Date de fin' AS title, COALESCE(l.end_date::TEXT, 'Bail en cours') AS description,
       CASE WHEN l.end_date IS NULL THEN 'green' ELSE NULL END AS color
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Loyer mensuel' AS title,
       to_char(l.monthly_rent, 'FM999G999D00') || ' €' AS description, 'cash' AS icon
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Charges' AS title,
       to_char(l.charges, 'FM999G999D00') || ' €/mois' AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Total mensuel (loyer + charges)' AS title,
       to_char(l.monthly_rent + l.charges, 'FM999G999D00') || ' €' AS description, 'calculator' AS icon
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Depot de garantie' AS title,
       COALESCE(to_char(l.deposit, 'FM999G999D00') || ' €', 'Non renseigne') AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Date de revision' AS title, COALESCE(l.revision_date::TEXT, 'Non definie') AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

SELECT 'Notes' AS title, COALESCE(l.notes, 'Aucune note') AS description
  FROM accounting.lease l WHERE l.id = $id::INT;

-- ── Actions ─────────────────────────────────────────────────────────────────

SELECT 'button' AS component, 'start' AS justify, 'sm' AS size;

SELECT 'Enregistrer un loyer' AS title, 'cash' AS icon, 'green' AS color,
       'rent_form.sql?lease_id=' || $id || '&month=' || EXTRACT(MONTH FROM CURRENT_DATE)::INT
           || '&year=' || EXTRACT(YEAR FROM CURRENT_DATE)::INT AS link
  FROM accounting.lease l WHERE l.id = $id::INT AND l.end_date IS NULL;

SELECT 'Voir le suivi des loyers' AS title, 'list-check' AS icon, 'cyan' AS outline,
       'rent.sql' AS link;

SELECT 'Mettre fin au bail' AS title, 'circle-x' AS icon, 'red' AS outline,
       'save_lease.sql?id=' || $id
           || '&tenant_id=' || l.tenant_id
           || '&property_id=' || l.property_id
           || '&start_date=' || l.start_date
           || '&end_date=' || CURRENT_DATE
           || '&monthly_rent=' || l.monthly_rent
           || '&charges=' || l.charges
       AS link
  FROM accounting.lease l WHERE l.id = $id::INT AND l.end_date IS NULL;

-- ── Paiements de loyer ──────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Historique des paiements' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Chaque paiement recu est enregistre ici avec la periode couverte et le mode de reglement. Les lignes vertes confirment la bonne reception.' AS contents,
       TRUE AS italics;

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Montant' AS align_right,
       'Aucun paiement enregistre pour ce bail. Utilisez le bouton "Enregistrer un loyer" ci-dessus.' AS empty_description;

SELECT to_char(make_date(rp.period_year, rp.period_month, 1), 'TMMonth YYYY') AS "Periode",
       rp.payment_date::TEXT AS "Date de paiement",
       to_char(rp.amount, 'FM999G999D00') || ' €' AS "Montant",
       CASE rp.payment_method
           WHEN 'transfer' THEN 'Virement'
           WHEN 'check' THEN 'Cheque'
           WHEN 'cash' THEN 'Especes'
           ELSE 'Autre' END AS "Mode",
       COALESCE(rp.notes, '') AS "Notes",
       'green' AS _sqlpage_color
  FROM accounting.rent_payment rp
 WHERE rp.lease_id = $id::INT
 ORDER BY rp.period_year DESC, rp.period_month DESC;
