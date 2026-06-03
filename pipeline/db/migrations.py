import logging
from pathlib import Path
from .connection import get_connection

log = logging.getLogger(__name__)

SCHEMA_FILE = Path(__file__).parent / "schema.sql"


def create_tables():
    sql = SCHEMA_FILE.read_text()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
    log.info("Schema applied successfully.")


def drop_all_tables(confirm: bool = False):
    if not confirm:
        raise RuntimeError("Pass confirm=True to drop all tables.")
    tables = [
        "fact_feature_abundance",
        "fact_denoising_stats",
        "fact_alpha_diversity",
        "fact_soil_chemistry",
        "dim_sample",
        "dim_soil_env",
        "dim_polymer",
        "dim_country",
        "dim_taxonomy",
        "dim_project",
    ]
    with get_connection() as conn:
        with conn.cursor() as cur:
            for t in tables:
                cur.execute(f"DROP TABLE IF EXISTS {t} CASCADE")
    log.warning("All tables dropped.")
