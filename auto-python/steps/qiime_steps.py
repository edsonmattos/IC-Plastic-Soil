import logging
import subprocess
from pathlib import Path
from utils.runner import run_cmd

logger = logging.getLogger(__name__)

# ── Helper ────────────────────────────────────────────────────────────────────

def _qiime(args: str, cfg: dict, log_file: Path) -> None:
    env = cfg["conda"]["qiime_env"]
    rc = run_cmd(f"qiime {args}", log_file=log_file, conda_env=env)
    if rc != 0:
        raise RuntimeError(f"Comando QIIME 2 falhou — veja {log_file}")


# ── Passo 2: Manifest ─────────────────────────────────────────────────────────

def build_manifest(cfg: dict, tracker, log_dir: Path) -> None:
    step = "02_build_manifest"
    if tracker.is_done(step):
        logger.info(f"[PULADO] {step}")
        return

    reads_dir = cfg["paths"]["reads_dir"]
    manifest   = cfg["paths"]["manifest"]
    mode       = cfg["sequencing"]["mode"]

    import sys, os
    sys.path.insert(0, str(Path(__file__).parents[2] / "scripts"))
    from build_manifest import find_paired, find_single, validate_sample_ids

    rows = find_paired(Path(reads_dir)) if mode == "paired" else find_single(Path(reads_dir))
    validate_sample_ids(rows)

    Path(manifest).parent.mkdir(parents=True, exist_ok=True)
    with open(manifest, "w") as fh:
        if mode == "paired":
            fh.write("sample-id\tforward-absolute-filepath\treverse-absolute-filepath\n")
            for r in rows:
                fh.write(f"{r['sample-id']}\t{r['forward']}\t{r['reverse']}\n")
        else:
            fh.write("sample-id\tabsolute-filepath\n")
            for r in rows:
                fh.write(f"{r['sample-id']}\t{r['absolute-filepath']}\n")

    logger.info(f"  Manifest gerado: {len(rows)} amostras → {manifest}")
    tracker.mark_done(step)
    logger.info(f"[✓] {step}")


# ── Passo 3: Import ───────────────────────────────────────────────────────────

def qiime_import(cfg: dict, tracker, log_dir: Path) -> None:
    step = "03_qiime_import"
    if tracker.is_done(step):
        logger.info(f"[PULADO] {step}")
        return

    outdir   = cfg["paths"]["outdir"]
    manifest = cfg["paths"]["manifest"]
    mode     = cfg["sequencing"]["mode"]

    seq_type = ("SampleData[PairedEndSequencesWithQuality]" if mode == "paired"
                else "SampleData[SequencesWithQuality]")
    fmt      = ("PairedEndFastqManifestPhred33V2" if mode == "paired"
                else "SingleEndFastqManifestPhred33V2")

    _qiime(
        f"tools import "
        f"--type '{seq_type}' "
        f"--input-path {manifest} "
        f"--input-format {fmt} "
        f"--output-path {outdir}/qza/demux.qza",
        cfg, log_dir / f"{step}.log"
    )
    tracker.mark_done(step)
    logger.info(f"[✓] {step}")


# ── Passo 4: DADA2 ───────────────────────────────────────────────────────────

def dada2(cfg: dict, tracker, log_dir: Path) -> None:
    step = "04_dada2"
    if tracker.is_done(step):
        logger.info(f"[PULADO] {step}")
        return

    outdir = cfg["paths"]["outdir"]
    d = cfg["dada2"]

    _qiime(
        f"dada2 denoise-paired "
        f"--i-demultiplexed-seqs {outdir}/qza/demux.qza "
        f"--p-trunc-len-f {d['trunc_f']} "
        f"--p-trunc-len-r {d['trunc_r']} "
        f"--p-trim-left-f {d['trim_left_f']} "
        f"--p-trim-left-r {d['trim_left_r']} "
        f"--p-max-ee-f {d['max_ee_f']} "
        f"--p-max-ee-r {d['max_ee_r']} "
        f"--p-n-threads {d['threads']} "
        f"--o-table {outdir}/qza/table.qza "
        f"--o-representative-sequences {outdir}/qza/rep-seqs.qza "
        f"--o-denoising-stats {outdir}/qza/denoising-stats.qza "
        f"--verbose",
        cfg, log_dir / f"{step}.log"
    )
    _qiime(
        f"metadata tabulate "
        f"--m-input-file {outdir}/qza/denoising-stats.qza "
        f"--o-visualization {outdir}/qza/denoising-stats.qzv",
        cfg, log_dir / f"{step}_viz.log"
    )
    tracker.mark_done(step)
    logger.info(f"[✓] {step}")


# ── Passo 5: Taxonomia ───────────────────────────────────────────────────────

def taxonomy(cfg: dict, tracker, log_dir: Path) -> None:
    step = "05_taxonomy"
    if tracker.is_done(step):
        logger.info(f"[PULADO] {step}")
        return

    outdir     = cfg["paths"]["outdir"]
    classifier = cfg["paths"]["classifier"]
    threads    = cfg["dada2"]["threads"]

    _qiime(
        f"feature-classifier classify-sklearn "
        f"--i-classifier {classifier} "
        f"--i-reads {outdir}/qza/rep-seqs.qza "
        f"--p-n-jobs {threads} "
        f"--o-classification {outdir}/taxonomy/taxonomy.qza",
        cfg, log_dir / f"{step}_classify.log"
    )
    _qiime(
        f"taxa filter-seqs "
        f"--i-sequences {outdir}/qza/rep-seqs.qza "
        f"--i-taxonomy {outdir}/taxonomy/taxonomy.qza "
        f"--p-exclude mitochondria,chloroplast "
        f"--p-mode contains "
        f"--o-filtered-sequences {outdir}/taxonomy/rep-seqs-filtered.qza",
        cfg, log_dir / f"{step}_filter_seqs.log"
    )
    tracker.mark_done(step)
    logger.info(f"[✓] {step}")


# ── Passo 6: Filtrar tabela ──────────────────────────────────────────────────

def filter_table(cfg: dict, tracker, log_dir: Path) -> None:
    step = "06_filter_table"
    if tracker.is_done(step):
        logger.info(f"[PULADO] {step}")
        return

    outdir   = cfg["paths"]["outdir"]
    metadata = cfg["paths"]["metadata"]

    _qiime(
        f"taxa filter-table "
        f"--i-table {outdir}/qza/table.qza "
        f"--i-taxonomy {outdir}/taxonomy/taxonomy.qza "
        f"--p-exclude mitochondria,chloroplast "
        f"--p-mode contains "
        f"--o-filtered-table {outdir}/qza/table-filtered.qza",
        cfg, log_dir / f"{step}.log"
    )
    _qiime(
        f"feature-table summarize "
        f"--i-table {outdir}/qza/table-filtered.qza "
        f"--m-sample-metadata-file {metadata} "
        f"--o-visualization {outdir}/qza/table-filtered.qzv",
        cfg, log_dir / f"{step}_viz.log"
    )
    tracker.mark_done(step)
    logger.info(f"[✓] {step}")


# ── Passo 7: Exportar ────────────────────────────────────────────────────────

def export(cfg: dict, tracker, log_dir: Path) -> None:
    step = "07_export"
    if tracker.is_done(step):
        logger.info(f"[PULADO] {step}")
        return

    outdir = cfg["paths"]["outdir"]
    env    = cfg["conda"]["qiime_env"]

    for cmd in [
        f"qiime tools export --input-path {outdir}/qza/table-filtered.qza --output-path {outdir}/exports/feature-table",
        f"biom convert -i {outdir}/exports/feature-table/feature-table.biom -o {outdir}/exports/feature-table.tsv --to-tsv",
        f"qiime tools export --input-path {outdir}/taxonomy/rep-seqs-filtered.qza --output-path {outdir}/exports",
        f"mv {outdir}/exports/dna-sequences.fasta {outdir}/exports/sequences.fasta",
        f"qiime tools export --input-path {outdir}/taxonomy/taxonomy.qza --output-path {outdir}/exports",
    ]:
        rc = run_cmd(cmd, log_file=log_dir / f"{step}.log", conda_env=env)
        if rc != 0:
            raise RuntimeError(f"Falha na exportação — veja {log_dir}/{step}.log")

    tracker.mark_done(step)
    logger.info(f"[✓] {step}")
