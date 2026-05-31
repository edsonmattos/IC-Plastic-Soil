# Contexto do Projeto — Pipeline 16S rRNA (QIIME 2)

## Visão geral

Pipeline de análise de microbioma 16S rRNA usando QIIME 2 (versão 2026.4).
Três projetos de sequenciamento sendo processados, cada um com características diferentes.

---

## Estrutura do repositório

```
auto-bash/
  run_pipeline.sh          # pipeline principal — roda tudo junto (usar este)
  run_per_sample.sh        # pipeline por amostra — banco de dados individual
  fluxo.md                 # guia de uso atualizado com todos os passos
  configs/
    projeto-01.conf        # V4, paired-end, 31 amostras (SRR15247053–83)
    projeto-02.conf        # V3-V4, paired-end, 25 amostras (ERR10890547–71)
    projeto-03.conf        # V3-V4, single-end (reads ~238-250 bp), 36 amostras
    projeto-01-single.conf # variante single do projeto-01 para comparação

scripts/
  build_manifest.py        # gera manifest QIIME 2 (suporta --recursive e single)
  04_download_silva_classifier.sh  # baixa classificador Silva 138 full-length
  05_validate_checklist.sh # checklist pós-pipeline

refs/
  silva-138-99-515-806-nb-classifier.qza  # classificador Silva 138 full-length
                                           # (nome V4 mas conteúdo full-length)

data/
  manifests/               # IDs SRA, manifests e metadata do projeto-01
  projeto-02/manifests/    # IDs SRA, manifests e metadata do projeto-02
  projeto-03/manifests/    # IDs SRA, manifests e metadata do projeto-03
  raw/                     # FASTQs — ignorado pelo git (**/raw/ no .gitignore)

results/
  projeto-01/              # resultados completos
  projeto-02/              # resultados completos
  projeto-03/              # em andamento (dada2 pendente)
```

---

## Estado atual de cada projeto

### Projeto-01 (PRJNA702448)
- **Amplicon**: V4 (515F/806R), 2×300 bp MiSeq
- **Primers**: já removidos nos dados brutos (TRIM_F=0, TRIM_R=0)
- **Parâmetros DADA2**: TRUNC_F=240, TRUNC_R=180, MAX_EE_F=2, MAX_EE_R=2
- **Etapas concluídas**: todas (download → rarefaction)
- **Observação**: amostras SRR15247053–57 têm taxa de quimeras anormalmente alta (90%+).
  Possível diferença de lote/biblioteca. Análise prosseguiu com SAMPLING_DEPTH=9000.
- **Arquivos de visualização** em `results/projeto-01/qzv/` e `results/projeto-01/diversity/`

### Projeto-02 (PRJNA não especificado)
- **Amplicon**: V3-V4 (341F/805R), 2×300 bp MiSeq
- **Primers**: presentes nos dados brutos (TRIM_F=17, TRIM_R=20)
- **Parâmetros DADA2**: TRUNC_F=270, TRUNC_R=250, MAX_EE_F=2, MAX_EE_R=4
- **Etapas concluídas**: todas (download → rarefaction)
- **Resultados**: excelentes — 62–72% merge, 61–70% non-chimeric de input
- **Arquivos de visualização** em `results/projeto-02/qzv/` e `results/projeto-02/diversity/`

### Projeto-03 (PRJNA1054347)
- **Amplicon**: V3-V4 (341F/806R), mas reads de ~236–250 bp (provavelmente 2×250 bp)
- **Modo**: **single-end obrigatório** — amplicon ~460 bp não permite overlap com reads de 250 bp
- **Primers**: presentes nos dados brutos, primer 341F tem 20 bp (ACTCCTACGGGNGGCWGCAG)
- **Parâmetros DADA2**: TRUNC_F=215, TRIM_F=20, MAX_EE_F=2 (SEQ_MODE=single)
  - TRUNC_F=215: mínimo seguro pois read mínima após TRIM é 216 bp (236-20)
- **Etapas concluídas**: download, manifest, import, quality
- **Próxima etapa**: `bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --step dada2`

---

## Decisões importantes e por quê

### Classificador Silva
O arquivo `refs/silva-138-99-515-806-nb-classifier.qza` é na verdade o **classificador
full-length** (não V4-específico). A URL do V4 retornou 404 para QIIME2 2026.4.
O full-length funciona para V4 e V3-V4. sklearn=1.4.2 nos dois.

### run_pipeline.sh vs run_per_sample.sh
- `run_pipeline.sh`: processa TODAS as amostras juntas num único demux.qza → DADA2 aprende
  modelo de erro com mais dados → melhor qualidade. **Usar este para análises.**
- `run_per_sample.sh`: processa cada amostra individualmente → resulta em
  `results/<PROJECT_NAME>/samples/<SRR>/`. Útil para banco de dados per-sample.

### RESULTS_BASE com PROJECT_NAME
O `run_per_sample.sh` usa `results/${PROJECT_NAME}/samples/` quando o conf define
`PROJECT_NAME`. Sem conf (só samples.txt), usa `results/samples/`.

### build_manifest.py --recursive
O `run_pipeline.sh` passa `--recursive` automaticamente. Encontra FASTQs em
subdirs (`data/raw/samples/SRR*/`) ou flat (`data/raw/projeto-01/`).

### Single-end com arquivos _1.fastq.gz
Quando `SEQ_MODE=single` e os arquivos são `_1.fastq.gz`/`_2.fastq.gz`
(estrutura paired baixada), o `build_manifest.py` usa automaticamente os `_1.fastq.gz`
como reads single-end.

---

## Problemas conhecidos e soluções

| Problema | Causa | Solução |
|---|---|---|
| `feature-table summarize` falha | API mudou no QIIME2 2026.4 (`--o-visualization` virou `--o-summary`) | Já corrigido no script |
| Metadata com IDs errados | Arquivo template sem IDs reais | O `--step manifest` agora gera automaticamente |
| Classificador 404 | URL V4 não existe para 2026.4 | Script usa fallback full-length (~208 MB) |
| `set -e` mata o script no wget 404 | `set -euo pipefail` interrompe em erro | Adicionado `|| true` no wget |
| Arquivo sra_ids com espaço no ID | Editor salvou espaço em vez de tab | `sed -i 's/^\(SRR[0-9]*\) /\1\t/'` |
| `build_manifest.py` não acha arquivos em single | `find_single` ignorava `_1.fastq.gz` | Corrigido para detectar R1 automaticamente |

---

## Como usar o pipeline em projeto novo

```bash
# 1. Criar conf baseado no template
cp auto-bash/configs/template.conf auto-bash/configs/projeto-XX.conf
# editar PROJECT_NAME, SRA_IDS_FILE, READS_DIR, MANIFEST, METADATA, OUTDIR

# 2. Baixar amostras
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --step download

# 3. Gerar manifest + metadata automaticamente
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --step manifest

# 4. Import + visualização de qualidade
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --from import --step quality

# 5. Ver demux-summary.qzv em view.qiime2.org → definir TRUNC_F, TRUNC_R

# 6. DADA2 (iterar até % non-chimeric > 50% e % merged > 60%)
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --step dada2
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --reset dada2 --step dada2

# 7. Resto do pipeline
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --from taxonomy
```

---

## Parâmetros de referência por tipo de amplicon

| Amplicon | Reads | TRIM_F | TRIM_R | TRUNC_F | TRUNC_R | Overlap |
|---|---|---|---|---|---|---|
| V4 (515F/806R) primers removidos | 2×300 | 0 | 0 | 240 | 180 | 167 bp |
| V3-V4 (341F/805R) primers presentes | 2×300 | 17-20 | 19-20 | 270 | 250 | ~23 bp |
| V3-V4 (341F/806R) primers presentes | 2×250 | 20 | — | 215 | — | single-end |

### Critérios de qualidade DADA2
- `% input passed filter` → deve ser > 85%
- `% input merged` → V4: >70% / V3-V4 2×300: >60% / single: não se aplica
- `% input non-chimeric` → deve ser > 50%
- `SAMPLING_DEPTH` → usar ~mínimo de reads não-quiméricas entre amostras

---

## Ambiente

- QIIME2: `conda activate qiime2-amplicon-2026.4`
- SRA Tools: `~/miniconda3/envs/sra-tools/bin/`
- sklearn no QIIME2: 1.4.2 (compatível com classificadores sklearn-1.4.2)
