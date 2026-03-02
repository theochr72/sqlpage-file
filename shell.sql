-- shell.sql — Layout commun (nav, thème, sidebar)
-- Inclus via: SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'shell' AS component,
       'InvoiceAI' AS title,
       'file-invoice' AS icon,
       TRUE AS sidebar,
       'dark' AS theme,
       'Inter' AS font,
       json('{"link":"/", "title":"Dashboard", "icon":"layout-dashboard"}') AS menu_item,
       json('{"link":"/invoices.sql", "title":"Invoices", "icon":"file-invoice"}') AS menu_item,
       json('{"link":"/tenants.sql", "title":"Tenants", "icon":"users"}') AS menu_item,
       json('{"link":"/rent.sql", "title":"Rent", "icon":"cash"}') AS menu_item,
       json('{"link":"/monthly.sql", "title":"Monthly", "icon":"calendar-month"}') AS menu_item,
       json('{"link":"/profitability.sql", "title":"Profitability", "icon":"chart-line"}') AS menu_item,
       json('{"link":"/recurring.sql", "title":"Recurring", "icon":"repeat"}') AS menu_item,
       json('{"link":"/fiscal.sql", "title":"Fiscal", "icon":"receipt-tax"}') AS menu_item,
       json('{"link":"/upload.sql", "title":"Upload", "icon":"upload"}') AS menu_item,
       json('{"link":"/properties.sql", "title":"Properties", "icon":"building"}') AS menu_item;
