#!/usr/bin/env python3
"""
invoice_insert.py - Extraire des factures PDF et les persister en base PostgreSQL
Usage: invoice_insert.py -k <api_key> <pdf_files...> [--schema SCHEMA] [--dryrun] [-v]
"""

import argparse
import configparser
import glob as glob_module
import json
import logging
import re
import subprocess
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

from pgcos import PgUtil

logger = logging.getLogger(__name__)


# ── Exceptions ────────────────────────────────────────────────────────────────


class ExtractionError(Exception):
    """Raised when invoice-extractor fails for a single file."""


# ── Helpers ────────────────────────────────────────────────────────────────────


def val(field):
    """Extrait .value depuis un champ invoice-extractor (dict ou scalaire)."""
    if isinstance(field, dict):
        return field.get("value")
    return field


def conf(field) -> float | None:
    """Extrait .confidence depuis un champ invoice-extractor."""
    if isinstance(field, dict):
        return field.get("confidence")
    return None


def compute_overall_confidence(data: dict) -> float | None:
    """Calcule la moyenne des scores de confiance de tous les champs."""
    scores = []

    for key in ("invoice_number", "document_type", "issue_date", "due_date",
                "total_amount", "currency"):
        c = conf(data.get(key))
        if c is not None:
            scores.append(c)

    supplier = data.get("supplier", {})
    for key in ("name", "vat_id", "address"):
        c = conf(supplier.get(key))
        if c is not None:
            scores.append(c)

    customer = data.get("customer", {})
    for key in ("name", "address"):
        c = conf(customer.get(key))
        if c is not None:
            scores.append(c)

    for item in data.get("items", []):
        for key in ("description", "quantity", "unit_price", "total"):
            c = conf(item.get(key))
            if c is not None:
                scores.append(c)

    return round(sum(scores) / len(scores), 4) if scores else None


def parse_fr_date(date_str: str | None):
    """Convertit DD/MM/YYYY → date Python, ou None si absent/invalide."""
    if not date_str:
        return None
    try:
        return datetime.strptime(date_str, "%d/%m/%Y").date()
    except ValueError:
        logger.warning("Cannot parse date: %s", date_str)
        return None


def parse_amount(value) -> float | None:
    """Convertit '7,50' ou '2.5' ou 7.5 en float Python."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    cleaned = str(value).replace("\xa0", "").replace(" ", "").replace(",", ".")
    try:
        return float(cleaned)
    except ValueError:
        logger.warning("Cannot parse amount: %r", value)
        return None


def slugify(text: str) -> str:
    """Convertit du texte en composant de nom de fichier sûr."""
    if not text:
        return "unknown"
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[-\s]+", "-", text)
    return text[:80] or "unknown"


def rename_pdf(pdf_path: Path, issue_date_str: str | None,
               supplier_name: str | None, invoice_number: str | None) -> Path:
    """Renomme le PDF en YYYY-MM-DD_fournisseur_numero.pdf sur place.
    Gère les conflits avec un suffixe numérique. Retourne le nouveau Path."""
    if issue_date_str:
        try:
            dt = datetime.strptime(issue_date_str, "%d/%m/%Y")
            date_part = dt.strftime("%Y-%m-%d")
        except ValueError:
            date_part = "unknown-date"
    else:
        date_part = "unknown-date"

    supplier_part = slugify(supplier_name) if supplier_name else "unknown-supplier"
    invoice_part = slugify(invoice_number) if invoice_number else "unknown-number"

    new_stem = f"{date_part}_{supplier_part}_{invoice_part}"
    new_name = f"{new_stem}.pdf"
    new_path = pdf_path.parent / new_name

    # Gestion des conflits de noms
    if new_path.exists() and new_path != pdf_path:
        counter = 1
        while True:
            new_name = f"{new_stem}_{counter}.pdf"
            new_path = pdf_path.parent / new_name
            if not new_path.exists():
                break
            counter += 1

    if new_path != pdf_path:
        pdf_path.rename(new_path)
        logger.info("Renamed %s -> %s", pdf_path.name, new_name)
    else:
        logger.info("File already has target name: %s", new_name)

    return new_path


def resolve_paths(patterns: list[str]) -> list[Path]:
    """Expanse les patterns glob et résout les chemins PDF existants."""
    paths = []
    for pattern in patterns:
        expanded = glob_module.glob(pattern, recursive=True)
        if not expanded:
            logger.warning("No files matched: %s", pattern)
            continue
        for p in expanded:
            p = Path(p)
            if p.is_file() and p.suffix.lower() == ".pdf":
                paths.append(p)
            else:
                logger.warning("Skipping non-PDF: %s", p)
    return sorted(set(paths))


# ── Extraction ─────────────────────────────────────────────────────────────────


def run_extractor(api_key: str, pdf_path: str) -> dict:
    """Lance invoice-extractor en subprocess et retourne le payload JSON."""
    cmd = ["invoice-extractor", "-k", api_key, pdf_path]
    logger.info("Running: %s", " ".join(cmd))

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        raise ExtractionError(
            f"invoice-extractor failed (rc={result.returncode}):\n{result.stderr}"
        )

    # Le banner ASCII est sur stdout ; le JSON est la dernière ligne débutant par '{'
    for line in reversed(result.stdout.splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except json.JSONDecodeError as exc:
                raise ExtractionError(f"JSON parse error: {exc}") from exc

    raise ExtractionError("Aucun payload JSON trouvé dans la sortie invoice-extractor")


# ── Insertion ──────────────────────────────────────────────────────────────────


def db_connection(database_configuration: dict) -> PgUtil:
    """Connect to db."""
    try:
        pg_db = PgUtil(database_configuration)
        pg_db.connect()
        return pg_db  # noqa: TRY300
    except Exception as err:
        logger.error(f"Could not connect to db database, error was: {err}")  # noqa: TRY400
        sys.exit(1)
    except not pg_db.is_connected():  # noqa: B030
        logger.exception("Could not connect to db database")
        sys.exit(1)


def insert_invoice(pg: PgUtil, data: dict, schema: str, dryrun: bool,
                   original_filename: str, renamed_filename: str) -> None:
    supplier = data.get("supplier", {})
    customer = data.get("customer", {})

    invoice_number   = val(data.get("invoice_number"))
    document_type    = val(data.get("document_type"))
    issue_date       = parse_fr_date(val(data.get("issue_date")))
    due_date         = parse_fr_date(val(data.get("due_date")))
    supplier_name    = val(supplier.get("name"))
    supplier_vat_id  = val(supplier.get("vat_id"))
    supplier_address = val(supplier.get("address"))
    customer_name    = val(customer.get("name"))
    customer_address = val(customer.get("address"))
    total_amount     = parse_amount(val(data.get("total_amount")))
    currency         = val(data.get("currency"))

    overall_confidence = compute_overall_confidence(data)

    # ── 1. En-tête facture ────────────────────────────────────────────────────
    statement = f"""
        INSERT INTO {schema}.invoice (
            invoice_number,   document_type,
            issue_date,       due_date,
            supplier_name,    supplier_vat_id,  supplier_address,
            customer_name,    customer_address,
            total_amount,     currency,
            invoice_number_confidence, document_type_confidence,
            issue_date_confidence,     due_date_confidence,
            supplier_name_confidence,  supplier_vat_id_confidence,
            supplier_address_confidence,
            customer_name_confidence,  customer_address_confidence,
            total_amount_confidence,   currency_confidence,
            original_filename, renamed_filename, raw_json,
            overall_confidence, status
        )
        VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s::jsonb, %s, 'pending_review'
        )
        ON CONFLICT (invoice_number) DO UPDATE SET
            document_type    = EXCLUDED.document_type,
            issue_date       = EXCLUDED.issue_date,
            due_date         = EXCLUDED.due_date,
            supplier_name    = EXCLUDED.supplier_name,
            supplier_vat_id  = EXCLUDED.supplier_vat_id,
            supplier_address = EXCLUDED.supplier_address,
            customer_name    = EXCLUDED.customer_name,
            customer_address = EXCLUDED.customer_address,
            total_amount     = EXCLUDED.total_amount,
            currency         = EXCLUDED.currency,
            invoice_number_confidence   = EXCLUDED.invoice_number_confidence,
            document_type_confidence    = EXCLUDED.document_type_confidence,
            issue_date_confidence       = EXCLUDED.issue_date_confidence,
            due_date_confidence         = EXCLUDED.due_date_confidence,
            supplier_name_confidence    = EXCLUDED.supplier_name_confidence,
            supplier_vat_id_confidence  = EXCLUDED.supplier_vat_id_confidence,
            supplier_address_confidence = EXCLUDED.supplier_address_confidence,
            customer_name_confidence    = EXCLUDED.customer_name_confidence,
            customer_address_confidence = EXCLUDED.customer_address_confidence,
            total_amount_confidence     = EXCLUDED.total_amount_confidence,
            currency_confidence         = EXCLUDED.currency_confidence,
            original_filename  = EXCLUDED.original_filename,
            renamed_filename   = EXCLUDED.renamed_filename,
            raw_json           = EXCLUDED.raw_json,
            overall_confidence = EXCLUDED.overall_confidence,
            processed_at       = now();
    """
    invoice_data = [
        invoice_number,   document_type,
        issue_date,       due_date,
        supplier_name,    supplier_vat_id,  supplier_address,
        customer_name,    customer_address,
        total_amount,     currency,
        # Confidence scores
        conf(data.get("invoice_number")),  conf(data.get("document_type")),
        conf(data.get("issue_date")),      conf(data.get("due_date")),
        conf(supplier.get("name")),        conf(supplier.get("vat_id")),
        conf(supplier.get("address")),
        conf(customer.get("name")),        conf(customer.get("address")),
        conf(data.get("total_amount")),    conf(data.get("currency")),
        # Metadata
        original_filename, renamed_filename,
        json.dumps(data, ensure_ascii=False),
        overall_confidence,
    ]

    logger.debug("Invoice INSERT:\n%s", pg.mogrify(statement=statement, data=invoice_data))
    if not dryrun:
        pg.execute(statement=statement, data=invoice_data)

    # ── 2. Lignes de facture ──────────────────────────────────────────────────
    # Supprime les anciennes lignes pour gérer le re-processing
    delete_stmt = f"DELETE FROM {schema}.invoice_item WHERE invoice_number = %s;"
    if not dryrun:
        pg.execute(statement=delete_stmt, data=[invoice_number])

    for idx, item in enumerate(data.get("items", []), start=1):
        statement = f"""
            INSERT INTO {schema}.invoice_item (
                invoice_number, item_index,
                description, quantity, unit_price, total,
                description_confidence, quantity_confidence,
                unit_price_confidence, total_confidence
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
        """
        item_data = [
            invoice_number, idx,
            val(item.get("description")),
            parse_amount(val(item.get("quantity"))),
            parse_amount(val(item.get("unit_price"))),
            parse_amount(val(item.get("total"))),
            conf(item.get("description")),
            conf(item.get("quantity")),
            conf(item.get("unit_price")),
            conf(item.get("total")),
        ]

        logger.debug("Item INSERT:\n%s", pg.mogrify(statement=statement, data=item_data))
        if not dryrun:
            pg.execute(statement=statement, data=item_data)

    if dryrun:
        logger.info("[DRYRUN] Facture %s — aucune donnée écrite.", invoice_number)
    else:
        logger.info("Facture %s insérée avec succès (confidence: %s).",
                     invoice_number,
                     f"{overall_confidence:.0%}" if overall_confidence else "N/A")


def parse_configuration(data_model: dict) -> dict:
    """Check and parse config file."""
    cfg_file = Path.home() / f".{Path(__file__).stem}.cfg"
    if not cfg_file.is_file():
        logger.error(f'could not find the config file "{cfg_file}"')
        sys.exit(1)
    raw_config = configparser.ConfigParser()
    raw_config.read(cfg_file)
    config = {section: dict.fromkeys(data_model[section]) for section in data_model}
    try:
        for section in config:  # noqa: PLC0206
            for item in config[section]:
                config[section][item] = raw_config.get(section, item)
    except (configparser.NoSectionError, configparser.NoOptionError) as err:
        logger.error(f"Invalid configuration: {err}")  # noqa: TRY400
        sys.exit(1)
    return config


# ── Entrée principale ──────────────────────────────────────────────────────────


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
    )

    parser = argparse.ArgumentParser(
        description="Extrait des factures PDF et les persiste en PostgreSQL"
    )
    parser.add_argument("-k", "--api-key", required=True,
                        help="Clé API OpenAI pour invoice-extractor")
    parser.add_argument("pdf", nargs="+",
                        help="Fichiers PDF ou patterns glob (ex: invoices/*.pdf)")
    parser.add_argument("--schema", default="accounting",
                        help="Schéma PostgreSQL cible (défaut: accounting)")
    parser.add_argument("--no-rename", action="store_true",
                        help="Ne pas renommer les fichiers PDF")
    parser.add_argument("--dryrun", action="store_true",
                        help="Affiche les requêtes sans les exécuter")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Active les logs DEBUG")
    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    pdf_paths = resolve_paths(args.pdf)
    if not pdf_paths:
        logger.error("No PDF files found")
        sys.exit(1)

    logger.info("Found %d PDF file(s) to process", len(pdf_paths))

    config = parse_configuration(
        {
            "invoice_db": ["host", "database", "port", "user", "password"],
        }
    )

    pg = db_connection(config["invoice_db"])

    errors = 0
    for idx, pdf_path in enumerate(pdf_paths, start=1):
        logger.info("Processing %s (%d/%d)", pdf_path.name, idx, len(pdf_paths))

        try:
            invoice_data = run_extractor(api_key=args.api_key, pdf_path=str(pdf_path))
        except ExtractionError as e:
            logger.error("Failed to extract %s: %s", pdf_path.name, e)
            errors += 1
            continue

        logger.debug("Payload extrait:\n%s",
                      json.dumps(invoice_data, indent=2, ensure_ascii=False))

        original_filename = pdf_path.name

        if args.no_rename or args.dryrun:
            renamed_filename = original_filename
        else:
            renamed_path = rename_pdf(
                pdf_path,
                issue_date_str=val(invoice_data.get("issue_date")),
                supplier_name=val(invoice_data.get("supplier", {}).get("name")),
                invoice_number=val(invoice_data.get("invoice_number")),
            )
            renamed_filename = renamed_path.name

        insert_invoice(
            pg=pg, data=invoice_data, schema=args.schema, dryrun=args.dryrun,
            original_filename=original_filename,
            renamed_filename=renamed_filename,
        )

    if errors:
        logger.warning("%d file(s) failed out of %d", errors, len(pdf_paths))
    else:
        logger.info("All %d file(s) processed successfully", len(pdf_paths))


if __name__ == "__main__":
    main()
