-- =============================================================================
-- MPB Pipeline — Star Schema
-- =============================================================================

-- DIMENSIONS ------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_project (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100) UNIQUE NOT NULL,
    bioproject      VARCHAR(50),
    amplicon        VARCHAR(30),
    seq_mode        VARCHAR(10),
    trim_f          INTEGER,
    trim_r          INTEGER,
    trunc_f         INTEGER,
    trunc_r         INTEGER,
    max_ee_f        NUMERIC(4,1),
    max_ee_r        NUMERIC(4,1),
    sampling_depth  INTEGER,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dim_taxonomy (
    id              SERIAL PRIMARY KEY,
    feature_id      VARCHAR(64) UNIQUE NOT NULL,
    domain          VARCHAR(100),
    phylum          VARCHAR(100),
    class           VARCHAR(100),
    "order"         VARCHAR(100),
    family          VARCHAR(100),
    genus           VARCHAR(100),
    species         VARCHAR(200),
    full_taxon      TEXT,
    confidence      NUMERIC(6,4)
);

CREATE TABLE IF NOT EXISTS dim_country (
    id              SERIAL PRIMARY KEY,
    country         VARCHAR(100) UNIQUE NOT NULL,
    climate         VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS dim_polymer (
    id                      SERIAL PRIMARY KEY,
    polymer_type            VARCHAR(100),
    polymer_size            VARCHAR(50),
    polymer_size_metric     VARCHAR(50),
    polymer_format          VARCHAR(50),
    polymer_color           VARCHAR(50),
    polymer_aromatic_rings  VARCHAR(20),
    biodegradable           VARCHAR(50),
    density                 VARCHAR(50),
    molecular_weight        VARCHAR(100),
    chemical_composition    VARCHAR(200),
    hardness                VARCHAR(50),
    degradability_rate      VARCHAR(50),
    plastic_groupping       VARCHAR(100),
    UNIQUE (polymer_type, polymer_format, polymer_color, polymer_size)
);

CREATE TABLE IF NOT EXISTS dim_soil_env (
    id              SERIAL PRIMARY KEY,
    soil_type       VARCHAR(150),
    soil_fraction   VARCHAR(50),
    sampling_depth  VARCHAR(50),
    cultivar        VARCHAR(100),
    experiment_type VARCHAR(50),
    env_type        VARCHAR(50),
    farm_system     VARCHAR(50),
    fertilization   VARCHAR(100),
    tillage         VARCHAR(100),
    UNIQUE (soil_type, soil_fraction, sampling_depth, cultivar,
            experiment_type, env_type, farm_system, fertilization, tillage)
);

CREATE TABLE IF NOT EXISTS dim_sample (
    id              SERIAL PRIMARY KEY,
    sample_id       VARCHAR(50)  UNIQUE NOT NULL,
    sample_name     VARCHAR(100),
    bioproject      VARCHAR(50),
    s16_region      VARCHAR(20),
    year_period     VARCHAR(50),
    sampling_season VARCHAR(50),
    project_id      INTEGER REFERENCES dim_project(id),
    country_id      INTEGER REFERENCES dim_country(id),
    polymer_id      INTEGER REFERENCES dim_polymer(id),
    soil_env_id     INTEGER REFERENCES dim_soil_env(id)
);

-- FACTS -----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fact_feature_abundance (
    id              BIGSERIAL PRIMARY KEY,
    sample_id       INTEGER NOT NULL REFERENCES dim_sample(id),
    project_id      INTEGER NOT NULL REFERENCES dim_project(id),
    taxonomy_id     INTEGER NOT NULL REFERENCES dim_taxonomy(id),
    read_count      INTEGER NOT NULL,
    UNIQUE (sample_id, taxonomy_id)
);

CREATE INDEX IF NOT EXISTS idx_feat_abund_sample    ON fact_feature_abundance(sample_id);
CREATE INDEX IF NOT EXISTS idx_feat_abund_taxonomy  ON fact_feature_abundance(taxonomy_id);
CREATE INDEX IF NOT EXISTS idx_feat_abund_project   ON fact_feature_abundance(project_id);

CREATE TABLE IF NOT EXISTS fact_denoising_stats (
    id                  SERIAL PRIMARY KEY,
    sample_id           INTEGER UNIQUE NOT NULL REFERENCES dim_sample(id),
    project_id          INTEGER NOT NULL REFERENCES dim_project(id),
    input_reads         INTEGER,
    filtered            INTEGER,
    denoised            INTEGER,
    merged              INTEGER,
    non_chimeric        INTEGER,
    pct_passed_filter   NUMERIC(5,2),
    pct_merged          NUMERIC(5,2),
    pct_non_chimeric    NUMERIC(5,2)
);

CREATE TABLE IF NOT EXISTS fact_alpha_diversity (
    id                  SERIAL PRIMARY KEY,
    sample_id           INTEGER UNIQUE NOT NULL REFERENCES dim_sample(id),
    project_id          INTEGER NOT NULL REFERENCES dim_project(id),
    shannon             NUMERIC(10,6),
    faith_pd            NUMERIC(10,6),
    observed_features   INTEGER,
    evenness            NUMERIC(10,6)
);

CREATE TABLE IF NOT EXISTS fact_soil_chemistry (
    id                          SERIAL PRIMARY KEY,
    sample_id                   INTEGER UNIQUE NOT NULL REFERENCES dim_sample(id),
    project_id                  INTEGER REFERENCES dim_project(id),
    annual_rainfall_mm          NUMERIC,
    avg_annual_temperature_c    NUMERIC,
    soil_temperature_c          NUMERIC,
    water_content_pct           NUMERIC,
    soc_g_per_kg                NUMERIC,
    tn_g_per_kg                 NUMERIC,
    cn_ratio                    NUMERIC,
    ph                          NUMERIC,
    doc_mg_per_kg               NUMERIC,
    din_mg_per_kg               NUMERIC,
    nh4_mg_per_kg               NUMERIC,
    no3_mg_per_kg               NUMERIC,
    ap_mg_per_kg                NUMERIC,
    ak_mg_per_kg                NUMERIC
);
