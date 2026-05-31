#!/usr/bin/env python3
"""
Gera o arquivo manifest.tsv no formato QIIME 2 a partir de um diretório de FASTQs.
Suporta single-end e paired-end.

Uso:
  python build_manifest.py --reads-dir data/raw --mode paired --output data/manifests/manifest.tsv

Convenção de nomes esperada:
  paired: <sample-id>_1.fastq.gz  e  <sample-id>_2.fastq.gz
          <sample-id>_R1.fastq.gz e  <sample-id>_R2.fastq.gz
  single: <sample-id>.fastq.gz
"""
import argparse
import os
import sys
from pathlib import Path


def find_paired(reads_dir: Path, recursive: bool = False) -> list[dict]:
    samples = {}
    pattern = "**/*.fastq.gz" if recursive else "*.fastq.gz"
    for f in sorted(reads_dir.glob(pattern)):
        name = f.name
        if "_1.fastq.gz" in name or "_R1.fastq.gz" in name:
            sid = name.replace("_1.fastq.gz", "").replace("_R1.fastq.gz", "")
            samples.setdefault(sid, {})["forward"] = str(f.resolve())
        elif "_2.fastq.gz" in name or "_R2.fastq.gz" in name:
            sid = name.replace("_2.fastq.gz", "").replace("_R2.fastq.gz", "")
            samples.setdefault(sid, {})["reverse"] = str(f.resolve())

    rows = []
    for sid, paths in sorted(samples.items()):
        if "forward" not in paths or "reverse" not in paths:
            print(f"[AVISO] Amostra {sid} está incompleta (faltando R1 ou R2), pulando.")
            continue
        rows.append({"sample-id": sid, **paths})
    return rows


def find_single(reads_dir: Path, recursive: bool = False) -> list[dict]:
    rows = []
    pattern = "**/*.fastq.gz" if recursive else "*.fastq.gz"
    all_files = sorted(reads_dir.glob(pattern))

    # Verifica se existem arquivos _1.fastq.gz (paired baixado, análise single)
    r1_files = [f for f in all_files
                if "_1.fastq.gz" in f.name or "_R1.fastq.gz" in f.name]
    plain_files = [f for f in all_files
                   if not any(t in f.name for t in ["_1.fastq.gz", "_2.fastq.gz", "_R1.", "_R2."])]

    # Usa _1.fastq.gz como single quando não há arquivos sem sufixo
    source = plain_files if plain_files else r1_files

    for f in source:
        sid = f.name.replace("_1.fastq.gz", "").replace("_R1.fastq.gz", "").replace(".fastq.gz", "")
        rows.append({"sample-id": sid, "absolute-filepath": str(f.resolve())})
    return rows


def validate_sample_ids(rows: list[dict]) -> None:
    """Valida que os IDs não têm espaços ou caracteres especiais (regra QIIME 2)."""
    import re
    pattern = re.compile(r'^[a-zA-Z0-9._-]+$')
    bad = [r["sample-id"] for r in rows if not pattern.match(r["sample-id"])]
    if bad:
        print("[ERRO] Os seguintes IDs contêm caracteres inválidos (use apenas letras, números, ., _, -):")
        for b in bad:
            print(f"  {b}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Gera manifest QIIME 2")
    parser.add_argument("--reads-dir", required=True, type=Path)
    parser.add_argument("--mode", choices=["paired", "single"], default="paired")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--recursive", action="store_true",
                        help="Buscar FASTQs em subdiretórios recursivamente")
    args = parser.parse_args()

    if not args.reads_dir.is_dir():
        print(f"[ERRO] Diretório não encontrado: {args.reads_dir}")
        sys.exit(1)

    rows = (find_paired(args.reads_dir, args.recursive)
            if args.mode == "paired"
            else find_single(args.reads_dir, args.recursive))

    if not rows:
        print(f"[ERRO] Nenhuma amostra encontrada em {args.reads_dir}")
        sys.exit(1)

    validate_sample_ids(rows)

    args.output.parent.mkdir(parents=True, exist_ok=True)

    with open(args.output, "w") as fh:
        if args.mode == "paired":
            fh.write("sample-id\tforward-absolute-filepath\treverse-absolute-filepath\n")
            for r in rows:
                fh.write(f"{r['sample-id']}\t{r['forward']}\t{r['reverse']}\n")
        else:
            fh.write("sample-id\tabsolute-filepath\n")
            for r in rows:
                fh.write(f"{r['sample-id']}\t{r['absolute-filepath']}\n")

    print(f"[OK] Manifest gerado com {len(rows)} amostras: {args.output}")


if __name__ == "__main__":
    main()
