# Roteiro Manual — Pipeline 16S rRNA sem Nextflow

Execução passo a passo usando QIIME 2 diretamente no terminal.  
Útil para rodar projeto a projeto com mais controle e visibilidade de cada etapa.

---

## Preparação

```bash
# Ativar o ambiente QIIME 2
source ~/miniconda3/etc/profile.d/conda.sh
conda activate qiime2-amplicon-2026.4

# Definir variáveis do projeto (edite conforme o projeto)
PROJECT="projeto-01"
THREADS=16
OUTDIR="results/${PROJECT}"
READS_DIR="data/raw/${PROJECT}"
MANIFEST="data/manifests/manifest_${PROJECT}.tsv"
METADATA="data/manifests/metadata_${PROJECT}.tsv"
CLASSIFIER="refs/silva-138-99-515-806-nb-classifier.qza"

mkdir -p ${OUTDIR}/qza ${OUTDIR}/taxonomy ${OUTDIR}/exports ${OUTDIR}/reports
```

---

## Passo 1 — Download das sequências (SRA Toolkit)

```bash
conda activate sra-tools

# Edite o arquivo com os SRA IDs do projeto
nano data/manifests/sra_ids_${PROJECT}.txt
# (um ID por linha, ex: SRR19868794)

# Baixar cada amostra
mkdir -p ${READS_DIR}

while read SRR; do
    [ -z "$SRR" ] && continue
    echo "Baixando: $SRR"
    prefetch ${SRR} --max-size 100g --output-directory ${READS_DIR}
    fasterq-dump ${SRR} \
        --outdir ${READS_DIR} \
        --threads ${THREADS} \
        --split-files
    pigz -p ${THREADS} ${READS_DIR}/${SRR}*.fastq
    rm -rf ${READS_DIR}/${SRR}/
    echo "Concluído: $SRR"
done < data/manifests/sra_ids_${PROJECT}.txt

conda activate qiime2-amplicon-2026.4
```

---

## Passo 2 — Gerar o Manifest QIIME 2

```bash
python3 scripts/build_manifest.py \
    --reads-dir ${READS_DIR} \
    --mode paired \
    --output ${MANIFEST}

# Verificar
head -5 ${MANIFEST}
wc -l ${MANIFEST}
```

---

## Passo 3 — Importar para QIIME 2

```bash
qiime tools import \
    --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path ${MANIFEST} \
    --input-format PairedEndFastqManifestPhred33V2 \
    --output-path ${OUTDIR}/qza/demux.qza

echo "Import concluído: $(ls -lh ${OUTDIR}/qza/demux.qza)"
```

> **QC opcional** — abre em https://view.qiime2.org
> ```bash
> qiime demux summarize \
>     --i-data ${OUTDIR}/qza/demux.qza \
>     --o-visualization ${OUTDIR}/qza/demux-summary.qzv \
>     --p-n 10000
> ```

---

## Passo 4 — DADA2: Denoising (ASVs)

Ajuste `--p-trunc-len-f` e `--p-trunc-len-r` com base no Q30 das suas amostras
(visualize o `demux-summary.qzv` para decidir os pontos de corte).

```bash
qiime dada2 denoise-paired \
    --i-demultiplexed-seqs ${OUTDIR}/qza/demux.qza \
    --p-trunc-len-f 280 \
    --p-trunc-len-r 235 \
    --p-trim-left-f 0 \
    --p-trim-left-r 0 \
    --p-max-ee-f 2 \
    --p-max-ee-r 2 \
    --p-n-threads ${THREADS} \
    --o-table ${OUTDIR}/qza/table.qza \
    --o-representative-sequences ${OUTDIR}/qza/rep-seqs.qza \
    --o-denoising-stats ${OUTDIR}/qza/denoising-stats.qza \
    --verbose

# Visualizar estatísticas (abre em view.qiime2.org)
qiime metadata tabulate \
    --m-input-file ${OUTDIR}/qza/denoising-stats.qza \
    --o-visualization ${OUTDIR}/qza/denoising-stats.qzv

echo "DADA2 concluído."
```

> **Critério de qualidade:** ≥ 70% dos reads devem passar o denoising.  
> Se estiver abaixo, aumente `--p-max-ee-f/r` ou reduza os truncamentos.

---

## Passo 5 — Classificação Taxonômica (Silva 138)

```bash
# Baixar o classificador se ainda não tiver
bash scripts/04_download_silva_classifier.sh

qiime feature-classifier classify-sklearn \
    --i-classifier ${CLASSIFIER} \
    --i-reads ${OUTDIR}/qza/rep-seqs.qza \
    --p-n-jobs ${THREADS} \
    --o-classification ${OUTDIR}/taxonomy/taxonomy.qza

# Visualizar
qiime metadata tabulate \
    --m-input-file ${OUTDIR}/taxonomy/taxonomy.qza \
    --o-visualization ${OUTDIR}/taxonomy/taxonomy.qzv

# Remover mitocôndrias e cloroplastos das sequências
qiime taxa filter-seqs \
    --i-sequences ${OUTDIR}/qza/rep-seqs.qza \
    --i-taxonomy ${OUTDIR}/taxonomy/taxonomy.qza \
    --p-exclude mitochondria,chloroplast \
    --p-mode contains \
    --o-filtered-sequences ${OUTDIR}/taxonomy/rep-seqs-filtered.qza

echo "Taxonomia concluída."
```

---

## Passo 6 — Filtrar Tabela de ASVs

```bash
qiime taxa filter-table \
    --i-table ${OUTDIR}/qza/table.qza \
    --i-taxonomy ${OUTDIR}/taxonomy/taxonomy.qza \
    --p-exclude mitochondria,chloroplast \
    --p-mode contains \
    --o-filtered-table ${OUTDIR}/qza/table-filtered.qza

# Resumo da tabela (requer metadata)
qiime feature-table summarize \
    --i-table ${OUTDIR}/qza/table-filtered.qza \
    --m-sample-metadata-file ${METADATA} \
    --o-visualization ${OUTDIR}/qza/table-filtered.qzv

echo "Tabela filtrada gerada."
```

---

## Passo 7 — Exportar para R (TSV + FASTA)

```bash
# Tabela de ASVs (BIOM → TSV)
qiime tools export \
    --input-path ${OUTDIR}/qza/table-filtered.qza \
    --output-path ${OUTDIR}/exports/feature-table

biom convert \
    -i ${OUTDIR}/exports/feature-table/feature-table.biom \
    -o ${OUTDIR}/exports/feature-table.tsv \
    --to-tsv

# Sequências representativas (FASTA)
qiime tools export \
    --input-path ${OUTDIR}/taxonomy/rep-seqs-filtered.qza \
    --output-path ${OUTDIR}/exports
mv ${OUTDIR}/exports/dna-sequences.fasta ${OUTDIR}/exports/sequences.fasta

# Taxonomia (TSV)
qiime tools export \
    --input-path ${OUTDIR}/taxonomy/taxonomy.qza \
    --output-path ${OUTDIR}/exports

echo "Exportação concluída. Arquivos em: ${OUTDIR}/exports/"
ls -lh ${OUTDIR}/exports/
```

---

## Passo 8 — Validação Rápida

```bash
bash scripts/05_validate_checklist.sh ${OUTDIR}
```

---

## Resumo de Arquivos Gerados

| Arquivo | Descrição |
|---|---|
| `exports/feature-table.tsv` | Tabela de ASVs por amostra (para R) |
| `exports/sequences.fasta` | Sequências representativas dos ASVs |
| `exports/taxonomy.tsv` | Classificação taxonômica de cada ASV |
| `qza/denoising-stats.qzv` | % reads que passaram o DADA2 |
| `taxonomy/taxonomy.qzv` | Visualização da taxonomia |

Todos os `.qzv` podem ser abertos em **https://view.qiime2.org**

---

## Dicas

- **Rodar em background** para etapas longas (DADA2, Taxonomia):
  ```bash
  nohup qiime dada2 denoise-paired [...] > logs/dada2_${PROJECT}.log 2>&1 & disown
  tail -f logs/dada2_${PROJECT}.log
  ```

- **Verificar se está rodando:**
  ```bash
  ps aux | grep qiime | grep -v grep
  ```

- **Retomar de uma etapa específica:** como cada passo gera um `.qza` independente, basta pular os passos já concluídos e continuar do ponto onde parou.
