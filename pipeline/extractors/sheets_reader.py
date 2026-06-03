"""Read sample metadata from Google Sheets."""
import logging
from pathlib import Path

import gspread
from google.oauth2.service_account import Credentials

from ..config import GOOGLE_CREDENTIALS_FILE, METADATA_SHEET, SPREADSHEET_ID

log = logging.getLogger(__name__)

SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets.readonly",
    "https://www.googleapis.com/auth/drive.readonly",
]

# Columns that carry numeric soil chemistry measurements.
# Values may use comma as decimal separator (European locale).
NUMERIC_COLS = {
    "ANNUAL_RAINFALL(mm)",
    "AVG_ANNUAL_TEMPERATURE",
    "SOIL_TEMPERATURE(C)",
    "WATER_CONTENT(%)",
    "SOC(g/kg)",
    "TN(g/kg)",
    "C/N",
    "pH",
    "DOC(mg/kg)",
    "DIN(mg/kg)",
    "NH4(mg/kg)",
    "NO3(mg/kg)",
    "AP(mg/kg)",
    "AK(mg/kg)",
}

_NA_VALUES = {"NA", "N/A", "na", "n/a", "", None}


def _na(val):
    return None if val in _NA_VALUES else val


def _to_float(val):
    if val in _NA_VALUES:
        return None
    try:
        return float(str(val).strip().replace(",", "."))
    except (ValueError, TypeError):
        return None


def _get_client() -> gspread.Client:
    if not GOOGLE_CREDENTIALS_FILE:
        raise RuntimeError(
            "GOOGLE_CREDENTIALS_FILE not set in .env. "
            "Point it to your Google service-account JSON."
        )
    creds = Credentials.from_service_account_file(
        GOOGLE_CREDENTIALS_FILE, scopes=SCOPES
    )
    return gspread.authorize(creds)


def fetch_metadata() -> list[dict]:
    """Return all rows from the metadata sheet as a list of dicts."""
    client = _get_client()
    spreadsheet = client.open_by_key(SPREADSHEET_ID)
    worksheet = spreadsheet.worksheet(METADATA_SHEET)
    # UNFORMATTED_VALUE retorna o valor numérico real armazenado (ex: 9.1),
    # evitando que gspread interprete a vírgula europeia como separador de milhar.
    records = worksheet.get_all_records(
        default_blank=None,
        value_render_option="UNFORMATTED_VALUE",
    )
    log.info("Fetched %d rows from Google Sheets (%s)", len(records), METADATA_SHEET)
    return records


def parse_sample_row(row: dict) -> dict:
    """Split a Sheets row into the sub-dicts used by each dimension/fact loader."""
    return {
        "sample": {
            "sample_id": _na(row.get("SAMPLE")),
            "sample_name": _na(row.get("SAMPLE_NAME")),
            "bioproject": _na(row.get("BIOPROJECT")),
            "s16_region": _na(row.get("16S_REGION")),
            "year_period": _na(row.get("YEAR_PERIOD")),
            "sampling_season": _na(row.get("SAMPLING_SEASON")),
        },
        "country": {
            "country": _na(row.get("COUNTRY")),
            "climate": _na(row.get("CLIMATE")),
        },
        "polymer": {
            "polymer_type": _na(row.get("POLYMER_TYPE")),
            "polymer_size": _na(row.get("POLYMER_SIZE")),
            "polymer_size_metric": _na(row.get("POLYMER_SIZE_METRIC")),
            "polymer_format": _na(row.get("POLYMER_FORMAT")),
            "polymer_color": _na(row.get("POLYMER_COLOR")),
            "polymer_aromatic_rings": _na(row.get("POLYMER_AROMATIC_RINGS")),
            "biodegradable": _na(row.get("BIODEGRADABLE")),
            "density": _na(row.get("DENSITY_(g/cm³)")),
            "molecular_weight": _na(row.get("MOLECULAR_WEIGHT_(g/mol)")),
            "chemical_composition": _na(row.get("CHEMICAL_COMPOSITION")),
            "hardness": _na(row.get("HARDNESS")),
            "degradability_rate": _na(row.get("DEGRADABILITY_RATE")),
            "plastic_groupping": _na(row.get("PLASTIC_GROUPPING")),
        },
        "soil_env": {
            "soil_type": _na(row.get("SOIL_TYPE")),
            "soil_fraction": _na(row.get("SOIL_FRACTION")),
            "sampling_depth": _na(str(row.get("SAMPLING_DEPTH", ""))),
            "cultivar": _na(row.get("CULTIVAR")),
            "experiment_type": _na(row.get("EXPERIMENT_TYPE")),
            "env_type": _na(row.get("ENV_TYPE")),
            "farm_system": _na(row.get("FARM_SYSTEM")),
            "fertilization": _na(row.get("FERTILIZATION")),
            "tillage": _na(row.get("TILLAGE")),
        },
        "soil_chemistry": {
            "annual_rainfall_mm": _to_float(row.get("ANNUAL_RAINFALL(mm)")),
            "avg_annual_temperature_c": _to_float(row.get("AVG_ANNUAL_TEMPERATURE")),
            "soil_temperature_c": _to_float(row.get("SOIL_TEMPERATURE(C)")),
            "water_content_pct": _to_float(row.get("WATER_CONTENT(%)")),
            "soc_g_per_kg": _to_float(row.get("SOC(g/kg)")),
            "tn_g_per_kg": _to_float(row.get("TN(g/kg)")),
            "cn_ratio": _to_float(row.get("C/N")),
            "ph": _to_float(row.get("pH")),
            "doc_mg_per_kg": _to_float(row.get("DOC(mg/kg)")),
            "din_mg_per_kg": _to_float(row.get("DIN(mg/kg)")),
            "nh4_mg_per_kg": _to_float(row.get("NH4(mg/kg)")),
            "no3_mg_per_kg": _to_float(row.get("NO3(mg/kg)")),
            "ap_mg_per_kg": _to_float(row.get("AP(mg/kg)")),
            "ak_mg_per_kg": _to_float(row.get("AK(mg/kg)")),
        },
    }
