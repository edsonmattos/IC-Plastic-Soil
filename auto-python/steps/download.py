import logging
from pathlib import Path
from utils.runner import run_cmd

logger = logging.getLogger(__name__)


def run(cfg: dict, tracker, log_dir: Path) -> None:
    step = "01_download_sra"
    if tracker.is_done(step):
        logger.info(f"[PULADO] {step}")
        return

    sra_file = Path(cfg["paths"]["sra_ids_file"])
    reads_dir = Path(cfg["paths"]["reads_dir"])
    threads = cfg["dada2"]["threads"]
    sra_env = cfg["conda"]["sra_env"]

    reads_dir.mkdir(parents=True, exist_ok=True)

    ids = [l.strip() for l in sra_file.read_text().splitlines()
           if l.strip() and not l.startswith("#")]

    logger.info(f"Download de {len(ids)} amostras → {reads_dir}")

    for srr in ids:
        existing = list(reads_dir.glob(f"{srr}*.fastq.gz"))
        if existing:
            logger.info(f"  Já existe: {srr} — pulando")
            continue

        logger.info(f"  Baixando: {srr}")
        cmd = (
            f"prefetch {srr} --max-size 100g --output-directory {reads_dir} && "
            f"fasterq-dump {srr} --outdir {reads_dir} --threads {threads} --split-files && "
            f"pigz -p {threads} {reads_dir}/{srr}*.fastq && "
            f"rm -rf {reads_dir}/{srr}/"
        )
        rc = run_cmd(cmd, log_file=log_dir / f"{step}_{srr}.log", conda_env=sra_env)
        if rc != 0:
            raise RuntimeError(f"Falha no download de {srr} — veja {log_dir}/{step}_{srr}.log")

    tracker.mark_done(step)
    logger.info(f"[✓] {step}")
