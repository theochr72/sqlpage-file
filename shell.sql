-- shell.sql — Layout commun (nav, theme, sidebar)
-- Inclus via: SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'shell' AS component,
       'Mon LMNP' AS title,
       'home-dollar' AS icon,
       TRUE AS sidebar,
       'dark' AS theme,
       'Inter' AS font,
       'Gestion locative simplifiee' AS footer,
       json('{"link":"/", "title":"Tableau de bord", "icon":"layout-dashboard"}') AS menu_item,
       json('{"link":"/properties.sql", "title":"Mes biens", "icon":"building"}') AS menu_item,
       json('{"link":"/tenants.sql", "title":"Locataires", "icon":"users"}') AS menu_item,
       json('{"link":"/leases.sql", "title":"Baux", "icon":"file-text"}') AS menu_item,
       json('{"link":"/rent.sql", "title":"Loyers", "icon":"cash"}') AS menu_item,
       json('{"link":"/monthly.sql", "title":"Bilan mensuel", "icon":"calendar-month"}') AS menu_item,
       json('{"link":"/profitability.sql", "title":"Rentabilite", "icon":"chart-line"}') AS menu_item,
       json('{"link":"/recurring.sql", "title":"Charges recurrentes", "icon":"repeat"}') AS menu_item,
       json('{"link":"/invoices.sql", "title":"Factures", "icon":"file-invoice"}') AS menu_item,
       json('{"link":"/fiscal.sql", "title":"Fiscal", "icon":"receipt-tax"}') AS menu_item,
       json('{"link":"/supplier_mappings.sql", "title":"Correspondances", "icon":"arrows-right-left"}') AS menu_item,
       json('{"link":"/upload.sql", "title":"Import", "icon":"upload"}') AS menu_item;
