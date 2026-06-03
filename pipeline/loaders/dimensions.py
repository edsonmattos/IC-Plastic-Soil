"""Upsert helpers for all dimension tables."""
import logging
import psycopg2.extras

log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# dim_project
# ---------------------------------------------------------------------------

def upsert_project(cur, meta: dict) -> int:
    cur.execute(
        """
        INSERT INTO dim_project
            (name, bioproject, amplicon, seq_mode,
             trim_f, trim_r, trunc_f, trunc_r,
             max_ee_f, max_ee_r, sampling_depth, updated_at)
        VALUES
            (%(name)s, %(bioproject)s, %(amplicon)s, %(seq_mode)s,
             %(trim_f)s, %(trim_r)s, %(trunc_f)s, %(trunc_r)s,
             %(max_ee_f)s, %(max_ee_r)s, %(sampling_depth)s, NOW())
        ON CONFLICT (name) DO UPDATE SET
            bioproject     = EXCLUDED.bioproject,
            amplicon       = COALESCE(EXCLUDED.amplicon, dim_project.amplicon),
            seq_mode       = EXCLUDED.seq_mode,
            trim_f         = EXCLUDED.trim_f,
            trim_r         = EXCLUDED.trim_r,
            trunc_f        = EXCLUDED.trunc_f,
            trunc_r        = EXCLUDED.trunc_r,
            max_ee_f       = EXCLUDED.max_ee_f,
            max_ee_r       = EXCLUDED.max_ee_r,
            sampling_depth = EXCLUDED.sampling_depth,
            updated_at     = NOW()
        RETURNING id
        """,
        {**meta, "bioproject": meta.get("bioproject"), "amplicon": meta.get("amplicon")},
    )
    return cur.fetchone()["id"]


def set_project_amplicon(cur, project_name: str, amplicon: str):
    cur.execute(
        "UPDATE dim_project SET amplicon = %s WHERE name = %s",
        (amplicon, project_name),
    )


# ---------------------------------------------------------------------------
# dim_taxonomy
# ---------------------------------------------------------------------------

def upsert_taxonomy_batch(cur, rows: list[dict]) -> dict[str, int]:
    """Upsert a batch of taxonomy rows. Returns {feature_id: id}."""
    if not rows:
        return {}
    psycopg2.extras.execute_values(
        cur,
        """
        INSERT INTO dim_taxonomy
            (feature_id, domain, phylum, class, "order", family,
             genus, species, full_taxon, confidence)
        VALUES %s
        ON CONFLICT (feature_id) DO UPDATE SET
            domain     = EXCLUDED.domain,
            phylum     = EXCLUDED.phylum,
            class      = EXCLUDED.class,
            "order"    = EXCLUDED."order",
            family     = EXCLUDED.family,
            genus      = EXCLUDED.genus,
            species    = EXCLUDED.species,
            full_taxon = EXCLUDED.full_taxon,
            confidence = EXCLUDED.confidence
        """,
        [
            (
                r["feature_id"], r.get("domain"), r.get("phylum"), r.get("class"),
                r.get("order"), r.get("family"), r.get("genus"), r.get("species"),
                r.get("full_taxon"), r.get("confidence"),
            )
            for r in rows
        ],
    )
    # Fetch the IDs back
    feature_ids = [r["feature_id"] for r in rows]
    cur.execute(
        "SELECT id, feature_id FROM dim_taxonomy WHERE feature_id = ANY(%s)",
        (feature_ids,),
    )
    return {row["feature_id"]: row["id"] for row in cur.fetchall()}


# ---------------------------------------------------------------------------
# dim_country
# ---------------------------------------------------------------------------

def upsert_country(cur, country: str, climate: str | None) -> int | None:
    if not country:
        return None
    cur.execute(
        """
        INSERT INTO dim_country (country, climate)
        VALUES (%s, %s)
        ON CONFLICT (country) DO UPDATE SET
            climate = COALESCE(EXCLUDED.climate, dim_country.climate)
        RETURNING id
        """,
        (country, climate),
    )
    return cur.fetchone()["id"]


# ---------------------------------------------------------------------------
# dim_polymer
# ---------------------------------------------------------------------------

def upsert_polymer(cur, data: dict) -> int | None:
    if not data.get("polymer_type"):
        return None
    cur.execute(
        """
        INSERT INTO dim_polymer
            (polymer_type, polymer_size, polymer_size_metric, polymer_format,
             polymer_color, polymer_aromatic_rings, biodegradable, density,
             molecular_weight, chemical_composition, hardness,
             degradability_rate, plastic_groupping)
        VALUES
            (%(polymer_type)s, %(polymer_size)s, %(polymer_size_metric)s, %(polymer_format)s,
             %(polymer_color)s, %(polymer_aromatic_rings)s, %(biodegradable)s, %(density)s,
             %(molecular_weight)s, %(chemical_composition)s, %(hardness)s,
             %(degradability_rate)s, %(plastic_groupping)s)
        ON CONFLICT (polymer_type, polymer_format, polymer_color, polymer_size)
        DO UPDATE SET
            polymer_aromatic_rings = EXCLUDED.polymer_aromatic_rings,
            biodegradable          = EXCLUDED.biodegradable,
            density                = EXCLUDED.density,
            molecular_weight       = EXCLUDED.molecular_weight,
            chemical_composition   = EXCLUDED.chemical_composition,
            hardness               = EXCLUDED.hardness,
            degradability_rate     = EXCLUDED.degradability_rate,
            plastic_groupping      = EXCLUDED.plastic_groupping
        RETURNING id
        """,
        data,
    )
    return cur.fetchone()["id"]


# ---------------------------------------------------------------------------
# dim_soil_env
# ---------------------------------------------------------------------------

def upsert_soil_env(cur, data: dict) -> int | None:
    if not any(data.values()):
        return None
    cur.execute(
        """
        INSERT INTO dim_soil_env
            (soil_type, soil_fraction, sampling_depth, cultivar,
             experiment_type, env_type, farm_system, fertilization, tillage)
        VALUES
            (%(soil_type)s, %(soil_fraction)s, %(sampling_depth)s, %(cultivar)s,
             %(experiment_type)s, %(env_type)s, %(farm_system)s,
             %(fertilization)s, %(tillage)s)
        ON CONFLICT (soil_type, soil_fraction, sampling_depth, cultivar,
                     experiment_type, env_type, farm_system, fertilization, tillage)
        DO UPDATE SET soil_type = EXCLUDED.soil_type
        RETURNING id
        """,
        data,
    )
    return cur.fetchone()["id"]


# ---------------------------------------------------------------------------
# dim_sample
# ---------------------------------------------------------------------------

def upsert_sample(cur, data: dict) -> int:
    cur.execute(
        """
        INSERT INTO dim_sample
            (sample_id, sample_name, bioproject, s16_region,
             year_period, sampling_season,
             project_id, country_id, polymer_id, soil_env_id)
        VALUES
            (%(sample_id)s, %(sample_name)s, %(bioproject)s, %(s16_region)s,
             %(year_period)s, %(sampling_season)s,
             %(project_id)s, %(country_id)s, %(polymer_id)s, %(soil_env_id)s)
        ON CONFLICT (sample_id) DO UPDATE SET
            sample_name     = COALESCE(EXCLUDED.sample_name,     dim_sample.sample_name),
            bioproject      = COALESCE(EXCLUDED.bioproject,      dim_sample.bioproject),
            s16_region      = COALESCE(EXCLUDED.s16_region,      dim_sample.s16_region),
            year_period     = COALESCE(EXCLUDED.year_period,     dim_sample.year_period),
            sampling_season = COALESCE(EXCLUDED.sampling_season, dim_sample.sampling_season),
            project_id      = COALESCE(EXCLUDED.project_id,      dim_sample.project_id),
            country_id      = COALESCE(EXCLUDED.country_id,      dim_sample.country_id),
            polymer_id      = COALESCE(EXCLUDED.polymer_id,      dim_sample.polymer_id),
            soil_env_id     = COALESCE(EXCLUDED.soil_env_id,     dim_sample.soil_env_id)
        RETURNING id
        """,
        data,
    )
    return cur.fetchone()["id"]


def get_sample_id(cur, sample_id_str: str) -> int | None:
    cur.execute("SELECT id FROM dim_sample WHERE sample_id = %s", (sample_id_str,))
    row = cur.fetchone()
    return row["id"] if row else None
