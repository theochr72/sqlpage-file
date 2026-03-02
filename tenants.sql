-- tenants.sql — Gestion des locataires

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- ── En-tete ─────────────────────────────────────────────────────────────────

SELECT 'hero' AS component,
       'Locataires' AS title,
       'Gerez votre carnet de locataires. Chaque fiche regroupe les coordonnees, l''historique des baux et les paiements associes.' AS description;

-- ── Formulaire d'ajout ──────────────────────────────────────────────────────

SELECT 'form' AS component,
       'POST' AS method,
       'save_tenant.sql' AS action,
       'Ajouter le locataire' AS validate,
       'plus' AS validate_icon,
       'green' AS validate_color,
       'Nouveau locataire' AS title;

SELECT 'text' AS type, 'name' AS name, 'Nom complet' AS label,
       TRUE AS required, 4 AS width,
       'Nom et prenom du locataire.' AS description;

SELECT 'email' AS type, 'email' AS name, 'Email' AS label, 4 AS width,
       'Pour le contacter en cas de besoin.' AS description;

SELECT 'tel' AS type, 'phone' AS name, 'Telephone' AS label, 4 AS width;

SELECT 'textarea' AS type, 'notes' AS name, 'Notes' AS label, 12 AS width, 2 AS rows,
       'Informations complementaires : garant, situation, etc.' AS description;

-- ── Liste des locataires ────────────────────────────────────────────────────

SELECT 'divider' AS component, 'Vos locataires' AS contents, 3 AS size;

SELECT 'alert' AS component,
       'user-plus' AS icon,
       'azure' AS color,
       'Aucun locataire enregistre' AS title,
       'Ajoutez votre premier locataire ci-dessus. Vous pourrez ensuite lui attribuer un bail sur un de vos biens.' AS description
 WHERE NOT EXISTS (SELECT 1 FROM accounting.tenant);

SELECT 'card' AS component, 3 AS columns;

SELECT t.name AS title,
       CASE WHEN t.email IS NOT NULL AND t.phone IS NOT NULL
            THEN t.email || ' — ' || t.phone
            WHEN t.email IS NOT NULL THEN t.email
            WHEN t.phone IS NOT NULL THEN t.phone
            ELSE 'Pas de coordonnees' END AS description,
       'user' AS icon,
       'tenant.sql?id=' || t.id AS link,
       CASE WHEN active_lease.property_name IS NOT NULL THEN 'green' ELSE 'azure' END AS color,
       COALESCE('Bail actif : ' || active_lease.property_name,
                'Aucun bail en cours') AS footer_md
  FROM accounting.tenant t
  LEFT JOIN LATERAL (
      SELECT p.name AS property_name
        FROM accounting.lease l
        JOIN accounting.property p ON p.id = l.property_id
       WHERE l.tenant_id = t.id AND l.end_date IS NULL
       LIMIT 1
  ) active_lease ON TRUE
 ORDER BY t.name;
