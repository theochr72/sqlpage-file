-- rent_form.sql — Enregistrer un paiement de loyer

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'breadcrumb' AS component;
SELECT 'Tableau de bord' AS title, '/' AS link;
SELECT 'Loyers' AS title, '/rent.sql' AS link;
SELECT 'Enregistrer un paiement' AS title, TRUE AS active;

-- ── Explication ─────────────────────────────────────────────────────────────

SELECT 'text' AS component;
SELECT 'Enregistrez ici la reception d''un loyer. Le montant est pre-rempli avec le total loyer + charges du bail selectionne. Vous pouvez l''ajuster si le paiement est partiel ou different.' AS contents,
       TRUE AS italics;

SELECT 'form' AS component,
       'POST' AS method,
       'save_rent.sql' AS action,
       'Enregistrer le paiement' AS validate,
       'device-floppy' AS validate_icon,
       'green' AS validate_color,
       'Saisie d''un paiement' AS title;

SELECT 'select' AS type, 'lease_id' AS name, 'Bail concerne' AS label,
       TRUE AS required, 6 AS width, TRUE AS dropdown, TRUE AS searchable,
       $lease_id AS value,
       'Selectionnez le bail pour lequel vous avez recu un paiement.' AS description,
       (SELECT json_agg(json_build_object(
           'label', t.name || ' — ' || p.name || ' (' || to_char(l.monthly_rent + l.charges, 'FM999G999D00') || ' €)',
           'value', l.id
       ) ORDER BY p.name)
          FROM accounting.lease l
          JOIN accounting.tenant t ON t.id = l.tenant_id
          JOIN accounting.property p ON p.id = l.property_id
         WHERE l.end_date IS NULL OR l.end_date >= CURRENT_DATE
       )::TEXT AS options;

SELECT 'select' AS type, 'period_month' AS name, 'Mois' AS label,
       TRUE AS required, 3 AS width, TRUE AS dropdown,
       COALESCE($month, EXTRACT(MONTH FROM CURRENT_DATE)::TEXT) AS value,
       'Mois concerne par ce paiement.' AS description,
       '[{"label":"Janvier","value":"1"},{"label":"Fevrier","value":"2"},{"label":"Mars","value":"3"},{"label":"Avril","value":"4"},{"label":"Mai","value":"5"},{"label":"Juin","value":"6"},{"label":"Juillet","value":"7"},{"label":"Aout","value":"8"},{"label":"Septembre","value":"9"},{"label":"Octobre","value":"10"},{"label":"Novembre","value":"11"},{"label":"Decembre","value":"12"}]' AS options;

SELECT 'number' AS type, 'period_year' AS name, 'Annee' AS label,
       TRUE AS required, 3 AS width,
       COALESCE($year, EXTRACT(YEAR FROM CURRENT_DATE)::TEXT) AS value;

SELECT 'number' AS type, 'amount' AS name, 'Montant recu (€)' AS label,
       TRUE AS required, 4 AS width, 0.01 AS step,
       'Pre-rempli avec loyer + charges. Ajustez si besoin.' AS description,
       COALESCE(
           (SELECT (l.monthly_rent + l.charges)::TEXT FROM accounting.lease l WHERE l.id = $lease_id::INT),
           ''
       ) AS value;

SELECT 'date' AS type, 'payment_date' AS name, 'Date de reception' AS label,
       TRUE AS required, 4 AS width,
       CURRENT_DATE::TEXT AS value,
       'Date a laquelle vous avez recu le paiement.' AS description;

SELECT 'select' AS type, 'payment_method' AS name, 'Mode de paiement' AS label,
       4 AS width, TRUE AS dropdown,
       'transfer' AS value,
       '[{"label":"Virement","value":"transfer"},{"label":"Cheque","value":"check"},{"label":"Especes","value":"cash"},{"label":"Autre","value":"other"}]' AS options;

SELECT 'textarea' AS type, 'notes' AS name, 'Notes' AS label, 12 AS width, 2 AS rows,
       'Informations complementaires : reference de virement, remarques, etc.' AS description;
