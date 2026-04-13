#!/usr/bin/env python3
"""
pipeline.py — Orquestrador do pipeline 16S rRNA (QIIME 2 direto)

Uso:
  python auto-python/pipeline.py auto-python/configs/projeto-01.yaml
  python auto-python/pipeline.py auto-python/configs/projeto-01.yaml --step dada2
  python auto-python/pipeline.py auto-python/configs/projeto-01.yaml --from taxonomy
  python auto-python/pipeline.py auto-python/configs/projeto-01.yaml --reset dada2
  python auto-python/pipeline.py auto-python/configs/projeto-01.yaml --reset-all
  python auto-python/pipeline.py --list-steps

Etapas disponíveis (use o nome curto):
  download   → Baixar sequências do SRA
  manifest   → Gerar manifest QIIME 2
  import     → Importar FASTQs para .qza
  dada2      → Denoising com DADA2
  taxonomy   → Classificação taxonômica (Silva)
  filter     → Filtrar mitocôndrias/cloroplastos
  export     → Exportar TSV + FASTA para R
"""
import sys
import argparse
import yaml
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent))

from utils.logger import setup_logger
from utils.runner import StepTracker
from steps import download, qiime_steps

# ── Mapeamento de nomes curtos → ID interno ───────────────────────────────────
ALIASES = {
    "download":  "01_download_sra",
    "manifest":  "02_build_manifest",
    "import":    "03_qiime_import",
    "qiime":     "03_qiime_import",
    "dada2":     "04_dada2",
    "taxonomy":  "05_taxonomy",
    "silva":     "05_taxonomy",
    "filter":    "06_filter_table",
    "export":    "07_export",
}

STEPS_ORDER = [
    "01_download_sra",
    "02_build_manifest",
    "03_qiime_import",
    "04_dada2",
    "05_taxonomy",
    "06_filter_table",
    "07_export",
]

STEPS_FN = {
    "01_download_sra":   download.run,
    "02_build_manifest": qiime_steps.build_manifest,
    "03_qiime_import":   qiime_steps.qiime_import,
    "04_dada2":          qiime_steps.dada2,
    "05_taxonomy":       qiime_steps.taxonomy,
    "06_filter_table":   qiime_steps.filter_table,
    "07_export":         qiime_steps.export,
}

STEPS_DESC = {
    "01_download_sra":   "Baixar sequências do SRA",
    "02_build_manifest": "Gerar manifest QIIME 2",
    "03_qiime_import":   "Importar FASTQs para .qza",
    "04_dada2":          "Denoising com DADA2",
    "05_taxonomy":       "Classificação taxonômica (Silva)",
    "06_filter_table":   "Filtrar mitocôndrias/cloroplastos",
    "07_export":         "Exportar TSV + FASTA para R",
}


def resolve(name: str) -> str:
    """Converte nome curto ou ID completo para o ID interno."""
    if name in STEPS_ORDER:
        return name
    if name in ALIASES:
        return ALIASES[name]
    validos = list(ALIASES.keys()) + STEPS_ORDER
    print(f"[ERRO] Etapa desconhecida: '{name}'")
    print(f"       Opções válidas: {', '.join(sorted(set(ALIASES.keys())))}")
    sys.exit(1)


def print_steps():
    print("\nEtapas disponíveis:\n")
    for sid in STEPS_ORDER:
        nomes_curtos = [k for k, v in ALIASES.items() if v == sid]
        aliases_str  = f"  (alias: {', '.join(nomes_curtos)})" if nomes_curtos else ""
        print(f"  {sid:<22} — {STEPS_DESC[sid]}{aliases_str}")
    print()


def main():
    parser = argparse.ArgumentParser(
        description="Pipeline 16S rRNA — QIIME 2",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("config", nargs="?", help="Arquivo YAML de configuração do projeto")
    parser.add_argument(
        "--step", dest="only_step", default=None,
        metavar="ETAPA",
        help="Rodar apenas esta etapa (ex: dada2, taxonomy, export)",
    )
    parser.add_argument(
        "--from", dest="from_step", default=None,
        metavar="ETAPA",
        help="Iniciar (e reforçar) a partir desta etapa (ex: dada2)",
    )
    parser.add_argument(
        "--skip", dest="skip_steps", default=None,
        metavar="ETAPA1,ETAPA2",
        help="Pular etapas específicas (ex: download,manifest)",
    )
    parser.add_argument(
        "--reset", dest="reset_step", default=None,
        metavar="ETAPA",
        help="Resetar uma etapa para forçar reexecução (ex: dada2)",
    )
    parser.add_argument(
        "--reset-all", action="store_true",
        help="Resetar todas as etapas",
    )
    parser.add_argument(
        "--list-steps", action="store_true",
        help="Listar todas as etapas disponíveis e sair",
    )
    args = parser.parse_args()

    if args.list_steps:
        print_steps()
        sys.exit(0)

    if not args.config:
        parser.print_help()
        sys.exit(1)

    cfg_path = Path(args.config)
    if not cfg_path.exists():
        print(f"[ERRO] Configuração não encontrada: {cfg_path}")
        sys.exit(1)

    with open(cfg_path) as f:
        cfg = yaml.safe_load(f)

    outdir  = cfg["paths"]["outdir"]
    log_dir = Path(outdir) / "reports"
    log_dir.mkdir(parents=True, exist_ok=True)

    logger  = setup_logger(cfg["project_name"], str(log_dir))
    tracker = StepTracker(outdir)

    logger.info("=" * 60)
    logger.info(f"  Projeto: {cfg['project_name']}")
    logger.info(f"  Config:  {cfg_path}")
    logger.info("=" * 60)

    # ── Resets ────────────────────────────────────────────────────────────────
    if args.reset_all:
        tracker.reset()
        logger.info("Todas as etapas foram resetadas.")
    elif args.reset_step:
        tracker.reset(resolve(args.reset_step))

    # ── Selecionar etapas ─────────────────────────────────────────────────────
    if args.only_step:
        steps = [resolve(args.only_step)]
        tracker.reset(steps[0])          # força reexecução da etapa isolada
        logger.info(f"Rodando apenas: {steps[0]}")

    elif args.from_step:
        start = resolve(args.from_step)
        idx   = STEPS_ORDER.index(start)
        steps = STEPS_ORDER[idx:]
        for s in steps:
            tracker.reset(s)
        logger.info(f"Reiniciando a partir de: {start}")

    else:
        steps = STEPS_ORDER

    # ── Pular etapas solicitadas ──────────────────────────────────────────────
    if args.skip_steps:
        skip = {resolve(s.strip()) for s in args.skip_steps.split(",")}
        steps = [s for s in steps if s not in skip]
        logger.info(f"Etapas puladas: {skip}")

    # ── Executar ──────────────────────────────────────────────────────────────
    for step in steps:
        fn = STEPS_FN.get(step)
        if fn is None:
            logger.warning(f"Etapa desconhecida: {step} — pulando")
            continue
        logger.info(f"▶ {step} — {STEPS_DESC[step]}")
        try:
            fn(cfg, tracker, log_dir)
        except RuntimeError as e:
            logger.error(str(e))
            logger.error(f"Pipeline interrompido na etapa: {step}")
            sys.exit(1)

    logger.info("=" * 60)
    logger.info(f"Concluído: {cfg['project_name']}")
    logger.info(f"Resultados: {outdir}/exports/")
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
