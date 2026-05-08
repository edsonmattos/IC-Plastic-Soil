# IC Plastic Soil — Pipeline 16S rRNA Microbioma

Pipeline de análise de microbioma do solo exposto a microplásticos via sequenciamento 16S rRNA.

Desenvolvido como Iniciação Científica na **UTFPR**, sob orientação da Profa. Deborah Leite.

---

## Visão Geral

```
Download SRA → Manifest → Import QIIME 2 → DADA2 → Taxonomia Silva 138 → Filtro → Export
```

| Etapa | Ferramenta | Saída |
|---|---|---|
| Download | SRA Toolkit | `.fastq.gz` |
| Import | QIIME 2 | `demux.qza` |
| Denoising | DADA2 | `table.qza`, `rep-seqs.qza` |
| Taxonomia | Silva 138 + sklearn | `taxonomy.qza` |
| Filtro | QIIME 2 | `table-filtered.qza` |
| Export | BIOM + QIIME 2 | `feature-table.tsv`, `sequences.fasta`, `taxonomy.tsv` |

---

## Modos de Execução

| Modo | Script | Quando usar |
|---|---|---|
| **Projeto** | `auto-bash/run_pipeline.sh` | Analisar amostras em conjunto (DADA2 batch) |
| **Por Amostra** | `auto-bash/run_per_sample.sh` | Banco de dados, amostras independentes |

Documentação completa dos scripts bash: [auto-bash/README.md](auto-bash/README.md)

---

## Requisitos

| Ferramenta | Versão | Ambiente Conda |
|---|---|---|
| Miniconda / Mamba | 3+ / 2.5+ | base |
| QIIME 2 Amplicon | 2026.4 | `qiime2-amplicon-2026.4` |
| SRA Toolkit | 3.1.1 | `sra-tools` |
| pigz | qualquer | sistema |

---

## Instalação

```bash
# 1. Miniconda
bash scripts/01_install_miniconda.sh && source ~/.bashrc

# 2. QIIME 2
bash scripts/02_install_qiime2_sra.sh

# 3. Classificador Silva 138 (V4, 515F/806R) — ~1GB
bash scripts/04_download_silva_classifier.sh
```

---

## Estrutura do Projeto

```
projeto-mpb/
├── auto-bash/
│   ├── run_pipeline.sh          # Modo projeto (batch)
│   ├── run_per_sample.sh        # Modo por amostra (banco de dados)
│   ├── README.md                # Documentação detalhada dos scripts
│   └── configs/
│       ├── template.conf        # Template de configuração
│       ├── projeto-01.conf      # Configuração do projeto 01
│       └── projeto-02.conf      # Configuração do projeto 02
├── data/
│   ├── raw/                     # FASTQs baixados (ignorado pelo git)
│   └── manifests/
│       ├── sra_ids_projeto-01.txt   # IDs + parâmetros DADA2 por amostra
│       ├── sra_ids_projeto-02.txt
│       └── metadata_projeto-XX.tsv  # Metadados das amostras
├── results/                     # Resultados gerados (ignorado pelo git)
│   ├── projeto-01/
│   ├── projeto-02/
│   └── samples/                 # Resultados por amostra (modo banco)
├── refs/                        # Classificador Silva (ignorado pelo git)
├── scripts/
│   ├── build_manifest.py        # Gerador de manifest QIIME 2
│   ├── 01_install_miniconda.sh
│   ├── 02_install_qiime2_sra.sh
│   ├── 04_download_silva_classifier.sh
│   └── 05_validate_checklist.sh
├── ROTEIRO_MANUAL.md            # Guia passo a passo sem scripts
└── main.nf                      # Pipeline Nextflow (alternativo)
```

---

## Formato do Arquivo de IDs

`data/manifests/sra_ids_projeto-XX.txt` — TSV com parâmetros por amostra:

```tsv
# sample_id    trunc_f  trunc_r  trim_f  trim_r  max_ee_f  max_ee_r  seq_mode
SRR15247053    280      235      0       0       2         2         paired
ERR10890547    270      240      17      20      2         4         paired
```

| Coluna | Descrição | Padrão |
|---|---|---|
| `sample_id` | ID do SRA (SRR/ERR/DRR) | — |
| `trunc_f` | Truncar forward em X bp | 280 |
| `trunc_r` | Truncar reverse em X bp | 235 |
| `trim_f` | Remover X bp do início forward (primers) | 0 |
| `trim_r` | Remover X bp do início reverse (primers) | 0 |
| `max_ee_f` | Máximo de erros esperados forward | 2 |
| `max_ee_r` | Máximo de erros esperados reverse | 2 |
| `seq_mode` | `paired` ou `single` | paired |

---

## Visualização dos Resultados

Arquivos `.qzv` são visualizados em **[view.qiime2.org](https://view.qiime2.org)** (arrastar e soltar):

| Arquivo | O que verificar |
|---|---|
| `demux-summary.qzv` | Qualidade por posição → define TRUNC_F/R |
| `denoising-stats.qzv` | % merged ≥ 70%, % filtered ≥ 80% |
| `taxonomy.qzv` | Predominância de Bacteria, pouco Unassigned |

---

## Referências

- [QIIME 2](https://qiime2.org/) — plataforma de análise de microbioma
- [SILVA 138](https://www.arb-silva.de/) — banco de dados taxonômico
- [nf-core/ampliseq](https://github.com/nf-core/ampliseq) — pipeline de referência
- [DADA2](https://benjjneb.github.io/dada2/) — denoising de amplicons
