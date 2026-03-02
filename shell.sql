-- shell.sql — Layout commun (nav, thème, sidebar)
-- Inclus via: SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

SELECT 'shell' AS component,
       'InvoiceAI' AS title,
       'file-invoice' AS icon,
       TRUE AS sidebar,
       'dark' AS theme,
       'Inter' AS font,
       json('{"link":"/", "title":"Dashboard", "icon":"menu"}') AS menu_item,
       json('{"link":"/invoices.sql", "title":"Invoices", "icon":"shopping-cart"}') AS menu_item,
       json('{"link":"/fiscal.sql", "title":"Fiscal", "icon":"alert-triangle"}') AS menu_item,
       json('{"link":"/upload.sql", "title":"Upload", "icon":"alert-triangle"}') AS menu_item,
       json('{"link":"/properties.sql", "title":"Properties", "icon":"mail"}') AS menu_item;
