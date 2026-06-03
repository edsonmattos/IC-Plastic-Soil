"""Parse bash-style KEY=VALUE project config files."""
import re
from pathlib import Path


def parse_conf(path: Path) -> dict:
    """Return a dict of KEY → value from a .conf file."""
    result = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, raw = line.partition("=")
        raw = raw.strip()
        # Extract value: quoted string OR bare word (stops at # or whitespace)
        m = re.match(r'^"([^"]*)"', raw) \
            or re.match(r"^'([^']*)'", raw) \
            or re.match(r'^([^#\s]*)', raw)
        value = m.group(1).strip() if m else ""
        result[key.strip()] = value or None
    return result


def _to_int(val):
    try:
        return int(str(val).strip()) if val else None
    except ValueError:
        return None


def _to_float(val):
    try:
        return float(str(val).strip()) if val else None
    except ValueError:
        return None


def extract_project_meta(conf_path: Path) -> dict:
    """Return a normalised dict ready to upsert into dim_project."""
    c = parse_conf(conf_path)
    return {
        "name": c.get("PROJECT_NAME"),
        "amplicon": None,           # filled later from Google Sheets (16S_REGION)
        "seq_mode": c.get("SEQ_MODE"),
        "trim_f": _to_int(c.get("TRIM_F")),
        "trim_r": _to_int(c.get("TRIM_R")),
        "trunc_f": _to_int(c.get("TRUNC_F")),
        "trunc_r": _to_int(c.get("TRUNC_R")),
        "max_ee_f": _to_float(c.get("MAX_EE_F")),
        "max_ee_r": _to_float(c.get("MAX_EE_R")),
        "sampling_depth": _to_int(c.get("SAMPLING_DEPTH")),
    }
