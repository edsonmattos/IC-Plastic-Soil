"""Read QIIME2 exports and QZA artifacts."""
import csv
import io
import logging
import zipfile
from pathlib import Path

log = logging.getLogger(__name__)

TAXON_PREFIXES = {
    "d__": "domain",
    "p__": "phylum",
    "c__": "class",
    "o__": "order",
    "f__": "family",
    "g__": "genus",
    "s__": "species",
}


# ---------------------------------------------------------------------------
# Taxonomy
# ---------------------------------------------------------------------------

def parse_taxon(taxon_string: str) -> dict:
    """Split a QIIME2 taxonomy string into its seven levels."""
    empty = {v: None for v in TAXON_PREFIXES.values()}
    if not taxon_string or taxon_string.strip() in ("Unassigned", ""):
        return empty
    result = dict(empty)
    for part in taxon_string.split(";"):
        part = part.strip()
        for prefix, field in TAXON_PREFIXES.items():
            if part.startswith(prefix):
                value = part[len(prefix):].strip()
                result[field] = value if value else None
                break
    return result


def read_taxonomy(project_dir: Path) -> list[dict]:
    """Return list of dicts from exports/taxonomy.tsv."""
    path = project_dir / "exports" / "taxonomy.tsv"
    if not path.exists():
        log.warning("taxonomy.tsv not found: %s", path)
        return []
    rows = []
    with open(path, newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            feature_id = row["Feature ID"]
            taxon_str = row.get("Taxon", "")
            confidence = _to_float(row.get("Confidence"))
            parsed = parse_taxon(taxon_str)
            rows.append({
                "feature_id": feature_id,
                "full_taxon": taxon_str if taxon_str != "Unassigned" else None,
                "confidence": confidence,
                **parsed,
            })
    return rows


# ---------------------------------------------------------------------------
# Feature table
# ---------------------------------------------------------------------------

def read_feature_table(project_dir: Path) -> list[dict]:
    """Return long-format list: {feature_id, sample_id, read_count}."""
    path = project_dir / "exports" / "feature-table.tsv"
    if not path.exists():
        log.warning("feature-table.tsv not found: %s", path)
        return []
    rows = []
    with open(path, newline="") as f:
        first_line = f.readline()
        # Skip comment lines starting with #
        while first_line.startswith("#OTU") is False and first_line.startswith("#"):
            first_line = f.readline()
        # first_line is now the header
        header = first_line.rstrip("\n").split("\t")
        otu_col = header[0]
        samples = header[1:]
        reader = csv.DictReader(f, fieldnames=header, delimiter="\t")
        for row in reader:
            feature_id = row[otu_col]
            for sample in samples:
                count = _to_float(row.get(sample, 0))
                if count and count > 0:
                    rows.append({
                        "feature_id": feature_id,
                        "sample_id": sample,
                        "read_count": int(count),
                    })
    return rows


# ---------------------------------------------------------------------------
# QZA helpers
# ---------------------------------------------------------------------------

def _read_qza_tsv(qza_path: Path) -> list[dict] | None:
    """Extract the first TSV from /data/ inside a QZA zip file."""
    if not qza_path.exists():
        return None
    with zipfile.ZipFile(qza_path) as z:
        candidates = [
            n for n in z.namelist()
            if "/data/" in n and n.endswith(".tsv")
        ]
        if not candidates:
            return None
        content = z.open(candidates[0]).read().decode("utf-8")
    lines = content.splitlines()
    # Skip comment/type rows (lines starting with #q2:)
    data_lines = [l for l in lines if not l.startswith("#q2:")]
    if not data_lines:
        return None
    reader = csv.DictReader(data_lines, delimiter="\t")
    return list(reader)


# ---------------------------------------------------------------------------
# Denoising stats
# ---------------------------------------------------------------------------

def read_denoising_stats(project_dir: Path) -> list[dict]:
    """Return DADA2 denoising stats per sample."""
    qza_path = project_dir / "qza" / "denoising-stats.qza"
    raw = _read_qza_tsv(qza_path)
    if raw is None:
        log.warning("denoising-stats.qza not found or empty: %s", qza_path)
        return []
    rows = []
    for r in raw:
        sid = r.get("sample-id") or r.get("sample_id")
        rows.append({
            "sample_id": sid,
            "input_reads": _to_int(r.get("input")),
            "filtered": _to_int(r.get("filtered")),
            "denoised": _to_int(r.get("denoised")),
            "merged": _to_int(r.get("merged")),
            "non_chimeric": _to_int(r.get("non-chimeric")),
            "pct_passed_filter": _to_float(r.get("percentage of input passed filter")),
            "pct_merged": _to_float(r.get("percentage of input merged")),
            "pct_non_chimeric": _to_float(r.get("percentage of input non-chimeric")),
        })
    return rows


# ---------------------------------------------------------------------------
# Alpha diversity
# ---------------------------------------------------------------------------

_DIVERSITY_FILES = {
    "shannon": ("shannon_vector.qza", "shannon_entropy"),
    "faith_pd": ("faith_pd_vector.qza", "faith_pd"),
    "evenness": ("evenness_vector.qza", "pielou_evenness"),
    "observed_features": ("observed_features_vector.qza", "observed_features"),
}


def read_alpha_diversity(project_dir: Path) -> list[dict]:
    """Merge all alpha-diversity metrics into one dict per sample."""
    div_dir = project_dir / "diversity"
    combined: dict[str, dict] = {}

    for metric, (filename, col) in _DIVERSITY_FILES.items():
        raw = _read_qza_tsv(div_dir / filename)
        if raw is None:
            continue
        for r in raw:
            sid = list(r.values())[0] if "" in r else r.get("sample-id", list(r.keys())[0])
            # The first column in alpha-diversity.tsv is the sample-id (sometimes unnamed)
            keys = list(r.keys())
            sid = r[keys[0]]
            val = _to_float(r.get(col) or r.get(keys[1] if len(keys) > 1 else col))
            if sid not in combined:
                combined[sid] = {"sample_id": sid}
            combined[sid][metric] = val

    return list(combined.values())


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _to_int(val):
    try:
        return int(float(str(val).strip())) if val not in (None, "", "NA") else None
    except (ValueError, TypeError):
        return None


def _to_float(val):
    if val in (None, "", "NA", "N/A"):
        return None
    try:
        return float(str(val).strip().replace(",", "."))
    except (ValueError, TypeError):
        return None
