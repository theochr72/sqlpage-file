-- invoice.sql — Detail d'une facture

SELECT 'dynamic' AS component, sqlpage.run_sql('shell.sql') AS properties;

-- Redirect si pas d'id valide
SELECT 'redirect' AS component, 'invoices.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

-- ── Breadcrumb ───────────────────────────────────────────────────────────────

SELECT 'breadcrumb' AS component;

SELECT 'Tableau de bord' AS title, '/' AS link;
SELECT 'Factures' AS title, '/invoices.sql' AS link;
SELECT i.invoice_number AS title, TRUE AS active
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Save feedback ─────────────────────────────────────────────────────────────

SELECT 'alert' AS component,
       'circle-check' AS icon,
       'green' AS color,
       'Modifications enregistrees.' AS title,
       TRUE AS dismissible
 WHERE $saved = '1';

-- ── Alerte si édité manuellement ──────────────────────────────────────────────

SELECT 'alert' AS component,
       'pencil' AS icon,
       'azure' AS color,
       'Modifie manuellement le ' || to_char(i.manually_edited_at, 'YYYY-MM-DD HH24:MI') AS title,
       'Champs : ' || array_to_string(i.manually_edited_fields, ', ')
           || '. La re-extraction ne remplacera pas ces modifications sauf avec --force.' AS description,
       TRUE AS dismissible
  FROM accounting.invoice i
 WHERE i.id = $id::INT AND i.manually_edited_at IS NOT NULL;

-- ── Status + actions (haut de page) ──────────────────────────────────────────

SELECT 'button' AS component, 'end' AS justify, 'sm' AS size;

SELECT 'Modifier' AS title,
       'azure' AS color,
       'pencil' AS icon,
       'edit_invoice.sql?id=' || $id AS link
  FROM accounting.invoice WHERE id = $id::INT;

SELECT 'Verifier' AS title,
       'cyan' AS color,
       'eye-check' AS icon,
       'review.sql?id=' || $id AS link
  FROM accounting.invoice WHERE id = $id::INT AND status = 'pending_review';

SELECT 'Valider' AS title,
       'green' AS color,
       'circle-check' AS icon,
       'update_status.sql?id=' || $id || '&status=validated' AS link
  FROM accounting.invoice WHERE id = $id::INT AND status != 'validated';

SELECT 'Rejeter' AS title,
       'red' AS outline,
       'circle-x' AS icon,
       'update_status.sql?id=' || $id || '&status=rejected' AS link,
       'confirm-reject' AS id
  FROM accounting.invoice WHERE id = $id::INT AND status != 'rejected';

SELECT 'Reinitialiser' AS title,
       'orange' AS outline,
       'clock' AS icon,
       'update_status.sql?id=' || $id || '&status=pending_review' AS link,
       'confirm-reset' AS id
  FROM accounting.invoice WHERE id = $id::INT AND status != 'pending_review';

-- ── KPIs de la facture ───────────────────────────────────────────────────────

SELECT 'big_number' AS component, 4 AS columns;

SELECT 'Total' AS title,
       COALESCE(i.total_amount::TEXT || ' ' || COALESCE(i.currency, ''), 'N/A') AS value,
       'currency-euro' AS icon,
       'green' AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Confiance' AS title,
       COALESCE(ROUND(i.overall_confidence * 100)::TEXT || '%', 'N/A') AS value,
       'target' AS icon,
       CASE WHEN i.overall_confidence >= 0.8 THEN 'green'
            WHEN i.overall_confidence >= 0.5 THEN 'orange'
            ELSE 'red' END AS color,
       ROUND(COALESCE(i.overall_confidence, 0) * 100)::INT AS progress_percent,
       CASE WHEN i.overall_confidence >= 0.8 THEN 'green'
            WHEN i.overall_confidence >= 0.5 THEN 'orange'
            ELSE 'red' END AS progress_color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Lignes' AS title,
       (SELECT COUNT(*) FROM accounting.invoice_item
         WHERE invoice_number = i.invoice_number)::TEXT AS value,
       'list-numbers' AS icon,
       'cyan' AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Statut' AS title,
       CASE WHEN i.status = 'pending_review' THEN 'En attente'
            WHEN i.status = 'validated' THEN 'Validee'
            WHEN i.status = 'rejected' THEN 'Rejetee'
       END AS value,
       CASE WHEN i.status = 'validated' THEN 'circle-check'
            WHEN i.status = 'rejected' THEN 'circle-x'
            ELSE 'clock' END AS icon,
       CASE WHEN i.status = 'validated' THEN 'green'
            WHEN i.status = 'rejected' THEN 'red'
            ELSE 'orange' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Informations fournisseur & client ────────────────────────────────────────

SELECT 'datagrid' AS component,
       'Fournisseur' AS title,
       'building' AS icon;

SELECT 'Nom' AS title,
       COALESCE(i.supplier_name, 'N/A') AS description,
       CASE WHEN COALESCE(i.supplier_name_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.supplier_name_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'N° TVA' AS title,
       COALESCE(i.supplier_vat_id, 'N/A') AS description,
       CASE WHEN COALESCE(i.supplier_vat_id_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.supplier_vat_id_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Adresse' AS title,
       COALESCE(i.supplier_address, 'N/A') AS description,
       CASE WHEN COALESCE(i.supplier_address_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.supplier_address_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'datagrid' AS component,
       'Client' AS title,
       'user' AS icon;

SELECT 'Nom' AS title,
       COALESCE(i.customer_name, 'N/A') AS description,
       CASE WHEN COALESCE(i.customer_name_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.customer_name_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Adresse' AS title,
       COALESCE(i.customer_address, 'N/A') AS description,
       CASE WHEN COALESCE(i.customer_address_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.customer_address_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Détails de la facture ────────────────────────────────────────────────────

SELECT 'datagrid' AS component,
       'Details de la facture' AS title,
       'file-text' AS icon;

SELECT 'Numero de facture' AS title,
       i.invoice_number AS description,
       CASE WHEN COALESCE(i.invoice_number_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.invoice_number_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Type de document' AS title,
       COALESCE(i.document_type, 'N/A') AS description,
       CASE WHEN COALESCE(i.document_type_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.document_type_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Date d''emission' AS title,
       COALESCE(i.issue_date::TEXT, 'N/A') AS description,
       CASE WHEN COALESCE(i.issue_date_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.issue_date_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Date d''echeance' AS title,
       COALESCE(i.due_date::TEXT, 'N/A') AS description,
       CASE WHEN COALESCE(i.due_date_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.due_date_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Total HT' AS title,
       COALESCE(i.total_ht::TEXT, 'N/A') AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'TVA' AS title,
       COALESCE(i.tva_amount::TEXT, 'N/A') AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Devise' AS title,
       COALESCE(i.currency, 'N/A') AS description,
       CASE WHEN COALESCE(i.currency_confidence, 0) >= 0.8 THEN 'green'
            WHEN COALESCE(i.currency_confidence, 0) >= 0.5 THEN 'orange'
            ELSE 'red' END AS color
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Fichiers & traitement ────────────────────────────────────────────────────

SELECT 'datagrid' AS component,
       'Informations de traitement' AS title,
       'settings' AS icon;

SELECT 'Fichier original' AS title,
       COALESCE(i.original_filename, 'N/A') AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Fichier renomme' AS title,
       COALESCE(i.renamed_filename, 'N/A') AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT 'Traite le' AS title,
       to_char(i.processed_at, 'YYYY-MM-DD HH24:MI:SS') AS description
  FROM accounting.invoice i WHERE i.id = $id::INT;

-- ── Lignes de facture ────────────────────────────────────────────────────────

SELECT 'title' AS component,
       'Lignes de facture' AS contents,
       3 AS level;

SELECT 'table' AS component,
       TRUE AS sort,
       'Quantite,Prix unitaire,Total,TVA %,Conf. desc.,Conf. qte,Conf. prix,Conf. total' AS align_right,
       TRUE AS hover,
       TRUE AS striped_rows,
       'Aucune ligne extraite.' AS empty_description;

SELECT item_index AS "#",
       description AS "Description",
       quantity::TEXT AS "Quantite",
       unit_price::TEXT AS "Prix unitaire",
       total::TEXT AS "Total",
       COALESCE(tva_rate::TEXT, '-') AS "TVA %",
       COALESCE(ROUND(description_confidence * 100)::TEXT || '%', '-') AS "Conf. desc.",
       COALESCE(ROUND(quantity_confidence * 100)::TEXT || '%', '-') AS "Conf. qte",
       COALESCE(ROUND(unit_price_confidence * 100)::TEXT || '%', '-') AS "Conf. prix",
       COALESCE(ROUND(total_confidence * 100)::TEXT || '%', '-') AS "Conf. total"
  FROM accounting.invoice_item
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
 ORDER BY item_index;

-- ── Confidence par champ (chart) ────────────────────────────────────────────

SELECT 'chart' AS component,
       'Confiance par champ' AS title,
       'bar' AS type,
       TRUE AS horizontal,
       0 AS ymin,
       1 AS ymax,
       300 AS height;

SELECT x, y FROM (
    SELECT 'N° Facture' AS x, i.invoice_number_confidence AS y, 1 AS ord FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Type doc.', i.document_type_confidence, 2 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Date emission', i.issue_date_confidence, 3 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Date echeance', i.due_date_confidence, 4 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Fournisseur', i.supplier_name_confidence, 5 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'N° TVA', i.supplier_vat_id_confidence, 6 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Adresse', i.supplier_address_confidence, 7 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Client', i.customer_name_confidence, 8 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Montant', i.total_amount_confidence, 9 FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 'Devise', i.currency_confidence, 10 FROM accounting.invoice i WHERE i.id = $id::INT
) sub
WHERE y IS NOT NULL
ORDER BY ord;

-- ── Retour ───────────────────────────────────────────────────────────────────

SELECT 'button' AS component, 'start' AS justify;

SELECT 'Retour aux factures' AS title,
       'arrow-left' AS icon,
       'invoices.sql' AS link;

-- ── Dialogues de confirmation pour actions destructives ──────────────────────

SELECT 'html' AS component;
SELECT '<script>
document.querySelectorAll("[id^=confirm-]").forEach(function(el) {
    var a = el.closest("a") || el.querySelector("a") || el;
    if (!a.href) return;
    a.addEventListener("click", function(e) {
        if (!confirm("Etes-vous sur de vouloir changer le statut de cette facture ?")) {
            e.preventDefault();
        }
    });
});
</script>' AS html;
