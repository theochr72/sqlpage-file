-- invoice.sql — Détail d'une facture

SELECT 'shell' AS component,
       'Invoice Detail' AS title,
       'file-invoice' AS icon,
       'Dashboard' AS menu_item,
       '/' AS link,
       'Invoices' AS menu_item,
       '/invoices.sql' AS link;

-- Redirect si pas d'id valide
SELECT 'redirect' AS component, 'invoices.sql' AS link
 WHERE $id IS NULL OR $id = '' OR $id !~ '^\d+$';

-- ── En-tête facture (datagrid) ───────────────────────────────────────────────

SELECT 'datagrid' AS component,
       i.invoice_number || ' — ' || COALESCE(i.supplier_name, 'Unknown') AS title,
       'file-invoice' AS icon
  FROM accounting.invoice i WHERE i.id = $id::INT;

SELECT title, description, color FROM (
    SELECT 1 AS ord, 'Invoice Number' AS title,
           i.invoice_number AS description,
           CASE WHEN i.invoice_number_confidence >= 0.8 THEN 'green'
                WHEN i.invoice_number_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END AS color
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 2, 'Document Type',
           COALESCE(i.document_type, 'N/A'),
           CASE WHEN i.document_type_confidence >= 0.8 THEN 'green'
                WHEN i.document_type_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 3, 'Supplier',
           COALESCE(i.supplier_name, 'N/A'),
           CASE WHEN i.supplier_name_confidence >= 0.8 THEN 'green'
                WHEN i.supplier_name_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 4, 'Supplier VAT ID',
           COALESCE(i.supplier_vat_id, 'N/A'),
           CASE WHEN i.supplier_vat_id_confidence >= 0.8 THEN 'green'
                WHEN i.supplier_vat_id_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 5, 'Supplier Address',
           COALESCE(i.supplier_address, 'N/A'),
           CASE WHEN i.supplier_address_confidence >= 0.8 THEN 'green'
                WHEN i.supplier_address_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 6, 'Customer',
           COALESCE(i.customer_name, 'N/A'),
           CASE WHEN i.customer_name_confidence >= 0.8 THEN 'green'
                WHEN i.customer_name_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 7, 'Customer Address',
           COALESCE(i.customer_address, 'N/A'),
           CASE WHEN i.customer_address_confidence >= 0.8 THEN 'green'
                WHEN i.customer_address_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 8, 'Issue Date',
           COALESCE(i.issue_date::TEXT, 'N/A'),
           CASE WHEN i.issue_date_confidence >= 0.8 THEN 'green'
                WHEN i.issue_date_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 9, 'Due Date',
           COALESCE(i.due_date::TEXT, 'N/A'),
           CASE WHEN i.due_date_confidence >= 0.8 THEN 'green'
                WHEN i.due_date_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 10, 'Total Amount',
           COALESCE(i.total_amount::TEXT || ' ' || COALESCE(i.currency, ''), 'N/A'),
           CASE WHEN i.total_amount_confidence >= 0.8 THEN 'green'
                WHEN i.total_amount_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 11, 'Overall Confidence',
           COALESCE(ROUND(i.overall_confidence * 100)::TEXT || '%', 'N/A'),
           CASE WHEN i.overall_confidence >= 0.8 THEN 'green'
                WHEN i.overall_confidence >= 0.5 THEN 'orange'
                ELSE 'red' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 12, 'Status',
           i.status,
           CASE WHEN i.status = 'validated' THEN 'green'
                WHEN i.status = 'rejected' THEN 'red'
                ELSE 'orange' END
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 13, 'Original File',
           COALESCE(i.original_filename, 'N/A'),
           NULL
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 14, 'Renamed File',
           COALESCE(i.renamed_filename, 'N/A'),
           NULL
      FROM accounting.invoice i WHERE i.id = $id::INT
    UNION ALL
    SELECT 15, 'Processed At',
           i.processed_at::TEXT,
           NULL
      FROM accounting.invoice i WHERE i.id = $id::INT
) sub ORDER BY ord;

-- ── Lignes de facture ────────────────────────────────────────────────────────

SELECT 'table' AS component,
       'Line Items' AS title,
       TRUE AS sort,
       'Quantity,Unit Price,Total' AS align_right,
       TRUE AS hover,
       TRUE AS striped_rows,
       'No line items.' AS empty_description;

SELECT item_index AS "#",
       description AS "Description",
       quantity::TEXT AS "Quantity",
       unit_price::TEXT AS "Unit Price",
       total::TEXT AS "Total",
       COALESCE(ROUND(description_confidence * 100)::TEXT || '%', '-') AS "Desc Conf",
       COALESCE(ROUND(quantity_confidence * 100)::TEXT || '%', '-') AS "Qty Conf",
       COALESCE(ROUND(unit_price_confidence * 100)::TEXT || '%', '-') AS "Price Conf",
       COALESCE(ROUND(total_confidence * 100)::TEXT || '%', '-') AS "Total Conf"
  FROM accounting.invoice_item
 WHERE invoice_number = (SELECT invoice_number FROM accounting.invoice WHERE id = $id::INT)
 ORDER BY item_index;

-- ── Boutons de changement de statut ──────────────────────────────────────────

SELECT 'button' AS component, 'center' AS justify;

SELECT 'Validate' AS title,
       'green' AS color,
       'check' AS icon,
       'update_status.sql?id=' || $id || '&status=validated' AS link
  FROM accounting.invoice WHERE id = $id::INT AND status != 'validated';

SELECT 'Reject' AS title,
       'red' AS color,
       'x' AS icon,
       'update_status.sql?id=' || $id || '&status=rejected' AS link
  FROM accounting.invoice WHERE id = $id::INT AND status != 'rejected';

SELECT 'Reset to Pending' AS title,
       'orange' AS color,
       'clock' AS icon,
       'update_status.sql?id=' || $id || '&status=pending_review' AS link
  FROM accounting.invoice WHERE id = $id::INT AND status != 'pending_review';

-- ── Lien retour ──────────────────────────────────────────────────────────────

SELECT 'button' AS component;

SELECT 'Back to list' AS title,
       'arrow-left' AS icon,
       'invoices.sql' AS link;
