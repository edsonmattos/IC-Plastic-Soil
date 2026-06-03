"""Insert / upsert helpers for all fact tables."""
import logging
import psycopg2.extras

log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# fact_feature_abundance
# ---------------------------------------------------------------------------

def insert_feature_abundance(cur, rows: list[dict]):
    """Bulk-upsert feature abundances.

    Each row must have: sample_db_id, project_db_id, taxonomy_db_id, read_count.
    """
    if not rows:
        return
    psycopg2.extras.execute_values(
        cur,
        """
        INSERT INTO fact_feature_abundance
            (sample_id, project_id, taxonomy_id, read_count)
        VALUES %s
        ON CONFLICT (sample_id, taxonomy_id) DO UPDATE SET
            read_count = EXCLUDED.read_count
        """,
        [
            (r["sample_db_id"], r["project_db_id"], r["taxonomy_db_id"], r["read_count"])
            for r in rows
        ],
        page_size=2000,
    )
    log.debug("Upserted %d feature-abundance rows.", len(rows))


# ---------------------------------------------------------------------------
# fact_denoising_stats
# ---------------------------------------------------------------------------

def upsert_denoising_stats(cur, sample_db_id: int, project_db_id: int, data: dict):
    cur.execute(
        """
        INSERT INTO fact_denoising_stats
            (sample_id, project_id, input_reads, filtered, denoised,
             merged, non_chimeric, pct_passed_filter, pct_merged, pct_non_chimeric)
        VALUES
            (%(sample_id)s, %(project_id)s, %(input_reads)s, %(filtered)s,
             %(denoised)s, %(merged)s, %(non_chimeric)s,
             %(pct_passed_filter)s, %(pct_merged)s, %(pct_non_chimeric)s)
        ON CONFLICT (sample_id) DO UPDATE SET
            input_reads       = EXCLUDED.input_reads,
            filtered          = EXCLUDED.filtered,
            denoised          = EXCLUDED.denoised,
            merged            = EXCLUDED.merged,
            non_chimeric      = EXCLUDED.non_chimeric,
            pct_passed_filter = EXCLUDED.pct_passed_filter,
            pct_merged        = EXCLUDED.pct_merged,
            pct_non_chimeric  = EXCLUDED.pct_non_chimeric
        """,
        {
            "sample_id": sample_db_id,
            "project_id": project_db_id,
            **{k: data.get(k) for k in (
                "input_reads", "filtered", "denoised", "merged", "non_chimeric",
                "pct_passed_filter", "pct_merged", "pct_non_chimeric",
            )},
        },
    )


# ---------------------------------------------------------------------------
# fact_alpha_diversity
# ---------------------------------------------------------------------------

def upsert_alpha_diversity(cur, sample_db_id: int, project_db_id: int, data: dict):
    cur.execute(
        """
        INSERT INTO fact_alpha_diversity
            (sample_id, project_id, shannon, faith_pd, observed_features, evenness)
        VALUES
            (%(sample_id)s, %(project_id)s, %(shannon)s,
             %(faith_pd)s, %(observed_features)s, %(evenness)s)
        ON CONFLICT (sample_id) DO UPDATE SET
            shannon           = EXCLUDED.shannon,
            faith_pd          = EXCLUDED.faith_pd,
            observed_features = EXCLUDED.observed_features,
            evenness          = EXCLUDED.evenness
        """,
        {
            "sample_id": sample_db_id,
            "project_id": project_db_id,
            "shannon": data.get("shannon"),
            "faith_pd": data.get("faith_pd"),
            "observed_features": data.get("observed_features"),
            "evenness": data.get("evenness"),
        },
    )


# ---------------------------------------------------------------------------
# fact_soil_chemistry
# ---------------------------------------------------------------------------

def upsert_soil_chemistry(cur, sample_db_id: int, project_db_id: int, data: dict):
    cur.execute(
        """
        INSERT INTO fact_soil_chemistry
            (sample_id, project_id,
             annual_rainfall_mm, avg_annual_temperature_c,
             soil_temperature_c, water_content_pct,
             soc_g_per_kg, tn_g_per_kg, cn_ratio, ph,
             doc_mg_per_kg, din_mg_per_kg,
             nh4_mg_per_kg, no3_mg_per_kg, ap_mg_per_kg, ak_mg_per_kg)
        VALUES
            (%(sample_id)s, %(project_id)s,
             %(annual_rainfall_mm)s, %(avg_annual_temperature_c)s,
             %(soil_temperature_c)s, %(water_content_pct)s,
             %(soc_g_per_kg)s, %(tn_g_per_kg)s, %(cn_ratio)s, %(ph)s,
             %(doc_mg_per_kg)s, %(din_mg_per_kg)s,
             %(nh4_mg_per_kg)s, %(no3_mg_per_kg)s, %(ap_mg_per_kg)s, %(ak_mg_per_kg)s)
        ON CONFLICT (sample_id) DO UPDATE SET
            project_id               = COALESCE(EXCLUDED.project_id, fact_soil_chemistry.project_id),
            annual_rainfall_mm       = EXCLUDED.annual_rainfall_mm,
            avg_annual_temperature_c = EXCLUDED.avg_annual_temperature_c,
            soil_temperature_c       = EXCLUDED.soil_temperature_c,
            water_content_pct        = EXCLUDED.water_content_pct,
            soc_g_per_kg             = EXCLUDED.soc_g_per_kg,
            tn_g_per_kg              = EXCLUDED.tn_g_per_kg,
            cn_ratio                 = EXCLUDED.cn_ratio,
            ph                       = EXCLUDED.ph,
            doc_mg_per_kg            = EXCLUDED.doc_mg_per_kg,
            din_mg_per_kg            = EXCLUDED.din_mg_per_kg,
            nh4_mg_per_kg            = EXCLUDED.nh4_mg_per_kg,
            no3_mg_per_kg            = EXCLUDED.no3_mg_per_kg,
            ap_mg_per_kg             = EXCLUDED.ap_mg_per_kg,
            ak_mg_per_kg             = EXCLUDED.ak_mg_per_kg
        """,
        {"sample_id": sample_db_id, "project_id": project_db_id, **data},
    )
