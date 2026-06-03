"""ETL orchestrator — one project at a time."""
import logging
from pathlib import Path

from .config import CONFIGS_DIR, RESULTS_DIR
from .db.connection import get_connection, get_cursor
from .extractors.conf_reader import extract_project_meta
from .extractors.qiime_reader import (
    read_alpha_diversity,
    read_denoising_stats,
    read_feature_table,
    read_taxonomy,
)
from .extractors.sheets_reader import fetch_metadata, parse_sample_row
from .loaders.dimensions import (
    get_sample_id,
    upsert_country,
    upsert_polymer,
    upsert_project,
    upsert_sample,
    upsert_soil_env,
    upsert_taxonomy_batch,
)
from .loaders.facts import (
    insert_feature_abundance,
    upsert_alpha_diversity,
    upsert_denoising_stats,
    upsert_soil_chemistry,
)

log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _discover_projects() -> list[Path]:
    """Return .conf files that have a matching directory under results/."""
    projects = []
    for conf in sorted(CONFIGS_DIR.glob("*.conf")):
        if conf.stem == "template":
            continue
        if not (RESULTS_DIR / conf.stem).is_dir():
            continue
        projects.append(conf)
    return projects


def _conf_for_project(name: str) -> Path | None:
    for conf in CONFIGS_DIR.glob("*.conf"):
        if conf.stem == name:
            return conf
    return None


# ---------------------------------------------------------------------------
# Step 1 — load one project from QIIME exports
# ---------------------------------------------------------------------------

def load_project(project_name: str):
    conf_path = _conf_for_project(project_name)
    if not conf_path:
        raise FileNotFoundError(f"No .conf found for project '{project_name}'")

    project_dir = RESULTS_DIR / project_name
    if not project_dir.exists():
        raise FileNotFoundError(f"Results directory not found: {project_dir}")

    log.info("=== Loading project: %s ===", project_name)

    meta = extract_project_meta(conf_path)
    taxonomy_rows = read_taxonomy(project_dir)
    feature_rows = read_feature_table(project_dir)
    denoising_rows = read_denoising_stats(project_dir)
    diversity_rows = read_alpha_diversity(project_dir)

    with get_connection() as conn:
        with get_cursor(conn) as cur:
            # 1 — dim_project
            project_db_id = upsert_project(cur, meta)
            log.info("Project '%s' → db id %d", project_name, project_db_id)

            # 2 — dim_taxonomy + collect id map
            tax_id_map = upsert_taxonomy_batch(cur, taxonomy_rows)
            log.info("Upserted %d taxonomy features.", len(tax_id_map))

            # 3 — dim_sample (basic, without Sheets metadata yet)
            all_sample_ids = {r["sample_id"] for r in feature_rows}
            all_sample_ids.update(r["sample_id"] for r in denoising_rows)
            all_sample_ids.update(r["sample_id"] for r in diversity_rows)

            sample_db_ids: dict[str, int] = {}
            for sid in all_sample_ids:
                db_id = upsert_sample(cur, {
                    "sample_id": sid,
                    "sample_name": None,
                    "bioproject": None,
                    "s16_region": None,
                    "year_period": None,
                    "sampling_season": None,
                    "project_id": project_db_id,
                    "country_id": None,
                    "polymer_id": None,
                    "soil_env_id": None,
                })
                sample_db_ids[sid] = db_id
            log.info("Upserted %d samples.", len(sample_db_ids))

            # 4 — fact_feature_abundance
            abundance_records = []
            for row in feature_rows:
                tax_id = tax_id_map.get(row["feature_id"])
                sample_db_id = sample_db_ids.get(row["sample_id"])
                if tax_id is None or sample_db_id is None:
                    continue
                abundance_records.append({
                    "sample_db_id": sample_db_id,
                    "project_db_id": project_db_id,
                    "taxonomy_db_id": tax_id,
                    "read_count": row["read_count"],
                })
            insert_feature_abundance(cur, abundance_records)
            log.info("Upserted %d feature-abundance records.", len(abundance_records))

            # 5 — fact_denoising_stats
            for row in denoising_rows:
                db_id = sample_db_ids.get(row["sample_id"])
                if db_id:
                    upsert_denoising_stats(cur, db_id, project_db_id, row)
            log.info("Upserted %d denoising-stats rows.", len(denoising_rows))

            # 6 — fact_alpha_diversity
            for row in diversity_rows:
                db_id = sample_db_ids.get(row["sample_id"])
                if db_id:
                    upsert_alpha_diversity(cur, db_id, project_db_id, row)
            log.info("Upserted %d alpha-diversity rows.", len(diversity_rows))

            # 7 — backfill project_id em fact_soil_chemistry para amostras que já
            #      tinham dados do Sheets inseridos antes deste projeto ser carregado
            cur.execute(
                """
                UPDATE fact_soil_chemistry f
                SET    project_id = %s
                FROM   dim_sample s
                WHERE  f.sample_id = s.id
                  AND  s.project_id = %s
                  AND  f.project_id IS NULL
                """,
                (project_db_id, project_db_id),
            )
            log.info("Backfilled project_id in fact_soil_chemistry for %d rows.", cur.rowcount)

    log.info("Project '%s' loaded successfully.", project_name)


# ---------------------------------------------------------------------------
# Step 2 — sync Google Sheets metadata into all dimension / fact tables
# ---------------------------------------------------------------------------

def sync_sheets():
    log.info("=== Syncing Google Sheets metadata ===")
    records = fetch_metadata()

    with get_connection() as conn:
        with get_cursor(conn) as cur:
            for record in records:
                parsed = parse_sample_row(record)
                sid = parsed["sample"]["sample_id"]
                if not sid:
                    continue

                # Ensure sample exists (it may not if QIIME data wasn't loaded yet)
                db_sample_id = get_sample_id(cur, sid)
                if db_sample_id is None:
                    log.debug("Sample %s not in DB yet — inserting stub.", sid)
                    db_sample_id = upsert_sample(cur, {
                        **parsed["sample"],
                        "project_id": None,
                        "country_id": None,
                        "polymer_id": None,
                        "soil_env_id": None,
                    })

                # Upsert dimensions
                country_id = upsert_country(
                    cur,
                    parsed["country"]["country"],
                    parsed["country"]["climate"],
                )
                polymer_id = upsert_polymer(cur, parsed["polymer"])
                soil_env_id = upsert_soil_env(cur, parsed["soil_env"])

                # Update dim_sample with Sheets metadata + FK references
                upsert_sample(cur, {
                    **parsed["sample"],
                    "project_id": None,   # keep existing (set by load_project)
                    "country_id": country_id,
                    "polymer_id": polymer_id,
                    "soil_env_id": soil_env_id,
                })

                # Update project amplicon from 16S_REGION in Sheets
                region = parsed["sample"].get("s16_region")
                if region:
                    bioproject = parsed["sample"].get("bioproject")
                    if bioproject:
                        cur.execute(
                            """
                            UPDATE dim_project p
                            SET    amplicon = %s
                            FROM   dim_sample s
                            WHERE  s.bioproject = %s
                              AND  s.project_id = p.id
                              AND  p.amplicon IS NULL
                            """,
                            (region, bioproject),
                        )

                # Soil chemistry fact
                upsert_soil_chemistry(cur, db_sample_id, _resolve_project_id(cur, db_sample_id), parsed["soil_chemistry"])

    log.info("Sheets sync complete — %d rows processed.", len(records))


def _resolve_project_id(cur, sample_db_id: int) -> int | None:
    cur.execute("SELECT project_id FROM dim_sample WHERE id = %s", (sample_db_id,))
    row = cur.fetchone()
    return row["project_id"] if row else None


# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

def run_all():
    for conf in _discover_projects():
        project_name = conf.stem
        try:
            load_project(project_name)
        except Exception as exc:
            log.error("Failed to load %s: %s", project_name, exc, exc_info=True)

    sync_sheets()


def list_projects() -> list[str]:
    return [c.stem for c in _discover_projects()]
