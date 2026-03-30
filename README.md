# IC Plastic Soil — Pipeline de Microbioma 16S rRNA

Pipeline automatizado para análise de microbioma do solo exposto a microplásticos, utilizando sequenciamento 16S rRNA (DADA2 + QIIME 2 + Nextflow).

Desenvolvido no contexto de Iniciação Científica na **UTFPR**, sob orientação da Profa. Deborah Leite.

---

## Visão Geral

O pipeline realiza as seguintes etapas:

1. **Download** das sequências brutas via SRA Toolkit (`prefetch` + `fasterq-dump`)
2. **Importação** para o formato QIIME 2 (`.qza`) via manifest
3. **Denoising** com DADA2 (`denoise-paired`) — geração de ASVs
4. **Classificação taxonômica** com classificador Silva 138
5. **Filtragem** de contaminantes (mitocôndrias e cloroplastos)
6. **Exportação** das tabelas (TSV) e sequências (FASTA) para análise em R

---

## Requisitos

| Ferramenta | Versão | Ambiente |
|---|---|---|
| Miniconda | 3+ | base |
| Mamba | 2.5+ | base |
| Nextflow | 25.10+ | `nextflow-env` |
| Java | 17 | `nextflow-env` |
| QIIME 2 | 2026.4 | `qiime2-amplicon-2026.4` |
| SRA Toolkit | 2.9+ | `qiime2-amplicon-2026.4` |

---

## Instalação

```bash
# 1. Miniconda
bash scripts/01_install_miniconda.sh
source ~/.bashrc

# 2. QIIME 2 + SRA Toolkit
bash scripts/02_install_qiime2_sra.sh

# 3. Nextflow + Java
bash scripts/03_install_nextflow.sh

# 4. Classificador Silva (região V4, 515F/806R)
bash scripts/04_download_silva_classifier.sh
```

---

## Estrutura do Projeto

```
projeto-mpb/
├── main.nf                        # Pipeline Nextflow principal
├── nextflow.config                # Configuração de perfis e recursos
├── scripts/
│   ├── 01_install_miniconda.sh
│   ├── 02_install_qiime2_sra.sh
│   ├── 03_install_nextflow.sh
│   ├── 04_download_silva_classifier.sh
│   ├── 05_validate_checklist.sh   # Checklist de validação dos resultados
│   └── build_manifest.py          # Gerador de manifest QIIME 2
├── data/
│   └── manifests/
│       ├── sra_ids.txt            # Lista de SRA IDs (um por linha)
│       └── metadata.tsv           # Metadados das amostras
└── results/                       # Saídas geradas pelo pipeline
    ├── qza/                       # Artefatos QIIME 2
    ├── taxonomy/                  # Classificação taxonômica
    └── exports/                   # TSV + FASTA para análise em R
```

---

## Como Usar

### Modo 1 — Download automático via SRA

Preencha `data/manifests/sra_ids.txt` com um SRA ID por linha, depois:

```bash
conda activate nextflow-env

nextflow run main.nf \
  --sra_ids data/manifests/sra_ids.txt \
  -profile local
```

### Modo 2 — FASTQs já disponíveis localmente

```bash
# Gerar manifest a partir dos FASTQs em data/raw/
python3 scripts/build_manifest.py \
  --reads-dir data/raw \
  --mode paired \
  --output data/manifests/manifest.tsv

nextflow run main.nf \
  --manifest data/manifests/manifest.tsv \
  -profile local
```

### Parâmetros principais

| Parâmetro | Padrão | Descrição |
|---|---|---|
| `--trunc_f` | 280 | Truncamento Forward (bp) |
| `--trunc_r` | 235 | Truncamento Reverse (bp) |
| `--threads` | 16 | Número de CPUs |
| `--paired_end` | true | `false` para single-end |

---

## Validação dos Resultados

```bash
bash scripts/05_validate_checklist.sh
```

Verifica automaticamente:
- Caracteres inválidos nos metadados
- Geração dos arquivos `.qzv`
- Porcentagem de reads que passaram pelo DADA2 (ideal ≥ 70%)
- Número de ASVs e sequências exportadas
- Cobertura da classificação taxonômica

Os arquivos `.qzv` podem ser visualizados em [view.qiime2.org](https://view.qiime2.org).

---

## Metadados

O arquivo `data/manifests/metadata.tsv` deve seguir o formato QIIME 2:

```tsv
#SampleID	tipo.plastico	concentracao.mg.kg	solo.origem
#q2:types	categorical	numeric	categorical
SRR001	PBAT	100	A
SRR002	blend.amido.poliester	500	B
```

> Use apenas letras, números, `.`, `_` e `-` nos nomes das amostras.

---

## Referências

- Pipeline de referência: [nf-core/ampliseq](https://github.com/nf-core/ampliseq)
- Banco de dados taxonômico: [SILVA 138](https://www.arb-silva.de/)
- Ferramenta de análise: [QIIME 2](https://qiime2.org/)
