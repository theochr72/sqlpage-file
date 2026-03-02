-- recurring.sql — Charges recurrentes

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── En-tete ─────────────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Charges recurrentes' AS title,
       'Definissez des modeles de depenses qui reviennent regulierement (assurance, charges de copro, taxe fonciere...). Chaque mois, generez automatiquement la facture correspondante en un clic.' AS description;

-- ── Periode courante ────────────────────────────────────────────────────────

SET _cur_month = EXTRACT(MONTH FROM CURRENT_DATE)::TEXT;
SET _cur_year  = EXTRACT(YEAR FROM CURRENT_DATE)::TEXT;

-- ── Formulaire d'ajout ──────────────────────────────────────────────────────

SELECT 'form' AS component,
       'POST' AS method,
       'save_recurring.sql' AS action,
       'Ajouter le modele' AS validate,
       'plus' AS validate_icon,
       'green' AS validate_color,
       'Nouveau modele de charge' AS title;

SELECT 'select' AS type, 'property_id' AS name, 'Bien concerne' AS label,
       TRUE AS required, 3 AS width, TRUE AS dropdown,
       'La charge sera rattachee a ce bien.' AS description,
       (SELECT json_agg(json_build_object('label', p.name, 'value', p.id) ORDER BY p.name)
          FROM accounting.property p)::TEXT AS options;

SELECT 'select' AS type, 'category_code' AS name, 'Categorie' AS label,
       3 AS width, TRUE AS dropdown, TRUE AS empty_option,
       'Categorie fiscale LMNP (optionnel).' AS description,
       (SELECT json_agg(json_build_object('label', c.label, 'value', c.code) ORDER BY c.sort_order)
          FROM accounting.expense_category c)::TEXT AS options;

SELECT 'text' AS type, 'supplier_name' AS name, 'Fournisseur' AS label, 3 AS width,
       'Ex: AXA, Syndic Martin...' AS placeholder;

SELECT 'text' AS type, 'description' AS name, 'Description' AS label,
       TRUE AS required, 3 AS width,
       'Ex: Assurance PNO, Charges copro T1...' AS placeholder;

SELECT 'number' AS type, 'amount' AS name, 'Montant (€)' AS label,
       TRUE AS required, 3 AS width, 0.01 AS step,
       'Montant de chaque echeance.' AS description;

SELECT 'select' AS type, 'frequency' AS name, 'Frequence' AS label,
       3 AS width, TRUE AS dropdown,
       '[{"label":"Mensuel","value":"monthly"},{"label":"Trimestriel","value":"quarterly"},{"label":"Annuel","value":"yearly"}]' AS options;

-- ── Tableau des modeles ─────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Vos modeles de charges' AS contents, 3 AS size;

SELECT 'text' AS component;
SELECT 'Chaque modele represente une charge recurrente. La colonne "Periode en cours" indique si la facture du mois a deja ete generee (**vert**) ou non (**orange** — cliquez sur la ligne pour generer).' AS contents_md;

SELECT 'alert' AS component,
       'repeat' AS icon,
       'azure' AS color,
       'Aucun modele de charge' AS title,
       'Creez votre premier modele ci-dessus. Par exemple : assurance habitation mensuelle, taxe fonciere annuelle, charges de copropriete trimestrielles.' AS description
 WHERE NOT EXISTS (SELECT 1 FROM accounting.recurring_expense);

SELECT 'table' AS component,
       TRUE AS sort, TRUE AS hover, TRUE AS striped_rows,
       'Montant' AS align_right,
       'Aucun modele de charge recurrente.' AS empty_description;

SELECT p.name AS "Bien",
       COALESCE(c.label, '—') AS "Categorie",
       COALESCE(re.supplier_name, '—') AS "Fournisseur",
       re.description AS "Description",
       to_char(re.amount, 'FM999G999D00') || ' €' AS "Montant",
       CASE re.frequency
           WHEN 'monthly' THEN 'Mensuel'
           WHEN 'quarterly' THEN 'Trimestriel'
           WHEN 'yearly' THEN 'Annuel' END AS "Frequence",
       CASE WHEN re.active THEN 'Actif' ELSE 'Inactif' END AS "Statut",
       CASE WHEN g.id IS NOT NULL THEN 'Generee' ELSE 'A generer' END AS "Periode en cours",
       CASE WHEN g.id IS NOT NULL THEN 'green' ELSE 'orange' END AS _sqlpage_color,
       CASE WHEN g.id IS NULL AND re.active
            THEN 'generate_recurring.sql?id=' || re.id
       END AS _sqlpage_id
  FROM accounting.recurring_expense re
  JOIN accounting.property p ON p.id = re.property_id
  LEFT JOIN accounting.expense_category c ON c.code = re.category_code
  LEFT JOIN accounting.recurring_expense_generation g
    ON g.recurring_expense_id = re.id
   AND g.period_year = $_cur_year::INT
   AND g.period_month = $_cur_month::INT
 ORDER BY p.name, re.description;
