# auto-bash — Scripts de Automação do Pipeline 16S

Este diretório contém os scripts bash para execução do pipeline de análise de microbioma 16S rRNA.

---

## Scripts Disponíveis

| Script | Modo | Uso |
|---|---|---|
| `run_pipeline.sh` | **Projeto** | DADA2 roda com todas as amostras juntas (batch) |
| `run_per_sample.sh` | **Por Amostra** | Cada amostra é processada individualmente |

---

## run_pipeline.sh — Modo Projeto

### Quando usar
Quando todas as amostras compartilham os mesmos parâmetros e serão analisadas em conjunto.
O DADA2 aprende o modelo de erro com todas as amostras — resultado mais preciso.

### Uso básico

```bash
# Rodar o pipeline completo
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf

# Ver etapas disponíveis
bash auto-bash/run_pipeline.sh --list
```

### Opções

| Opção | Descrição | Exemplo |
|---|---|---|
| `--step ETAPA` | Rodar apenas uma etapa | `--step dada2` |
| `--from ETAPA` | Iniciar a partir desta etapa | `--from taxonomy` |
| `--skip ETAPA` | Pular uma etapa | `--skip quality` |
| `--reset ETAPA` | Resetar etapa (apaga arquivos + marca) | `--reset dada2` |
| `--reset-all` | Resetar todas as etapas | |
| `--list` | Listar etapas disponíveis | |

### Etapas e nomes aceitos

| Nome curto | ID interno | Descrição |
|---|---|---|
| `download` | `01_download_sra` | Download via SRA Toolkit |
| `manifest` | `02_build_manifest` | Gerar manifest QIIME 2 |
| `import` | `03_qiime_import` | Importar FASTQs para `.qza` |
| `quality` | `03b_demux_summary` | Visualização de qualidade (`.qzv`) |
| `dada2` | `04_dada2` | Denoising DADA2 |
| `taxonomy` | `05_taxonomy` | Classificação Silva 138 |
| `filter` | `06_filter_table` | Filtrar mitocôndrias/cloroplastos |
| `export` | `07_export` | Exportar TSV + FASTA |

### Exemplos práticos

```bash
# 1. Pipeline completo do zero
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf

# 2. Só baixar as sequências
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --step download

# 3. Só gerar o manifest
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --step manifest

# 4. Gerar visualização de qualidade para definir TRUNC_F/R
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --step quality
#    → Abrir results/projeto-01/qza/demux-summary.qzv em view.qiime2.org

# 5. Rodar só o DADA2 após ajustar parâmetros
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --step dada2

# 6. DADA2 falhou ou parâmetros mudaram → resetar e rerodar
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --reset dada2 --step dada2

# 7. Rerodar a partir da taxonomia
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --from taxonomy

# 8. Rodar tudo do zero (ignora etapas concluídas)
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --reset-all

# 9. Já sabe os parâmetros TRUNC/TRIM → pular quality e ir direto para DADA2
#    (requer download, manifest e import já concluídos)
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --from dada2
```

### Fluxo recomendado (primeira vez)

```bash
# Passo 1: baixar
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --reset download --step download

# Passo 2: manifest
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --reset manifest --step manifest

# Passo 3: import
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --reset import --step import

# Passo 4: visualizar qualidade → abre .qzv em view.qiime2.org
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --reset quality --step quality
#    Analise o gráfico e ajuste TRUNC_F e TRUNC_R no .conf

# Passo 5: DADA2 (com parâmetros ajustados)
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --step dada2
#    Verifique denoising-stats.qzv: merged ≥ 70%, filtered ≥ 80%

# Passo 6: taxonomia, filtro e export
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-01.conf --from taxonomy
```

---

## run_per_sample.sh — Modo Por Amostra

### Quando usar
Quando cada amostra é independente e os resultados são usados individualmente
(ex: construção de banco de dados com amostras de diferentes estudos, primers ou condições).

Cada amostra tem seus próprios parâmetros definidos no arquivo TSV de IDs.
Os resultados ficam em `results/samples/<sample_id>/exports/`.

### Uso básico

```bash
# Processar todas as amostras do projeto (lê o .txt indicado no .conf)
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf

# Ou passando o arquivo .txt diretamente
bash auto-bash/run_per_sample.sh data/manifests/sra_ids_projeto-01.txt

# Ver etapas disponíveis
bash auto-bash/run_per_sample.sh --list
```

### Opções

| Opção | Descrição | Exemplo |
|---|---|---|
| `--only AMOSTRA` | Processar apenas uma amostra | `--only SRR15247053` |
| `--step ETAPA` | Rodar apenas uma etapa (em todas) | `--step dada2` |
| `--from ETAPA` | Iniciar a partir desta etapa | `--from taxonomy` |
| `--skip ETAPA` | Pular uma etapa | `--skip quality` |
| `--reset ETAPA` | Resetar etapa de todas as amostras | `--reset dada2` |
| `--reset-all` | Resetar tudo | |
| `--list` | Listar etapas disponíveis | |

### Exemplos práticos

```bash
# 1. Processar todas as amostras do início ao fim
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf

# 2. Processar apenas uma amostra específica
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf \
    --only SRR15247053

# 3. Só baixar todas as amostras
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf --step download

# 4. Só gerar os manifests (requer download concluído)
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf --step manifest

# 5. Só importar para .qza (requer manifest concluído)
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf --step import

# 6. DADA2 falhou em uma amostra → resetar e rerodar só ela
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf \
    --only SRR15247053 --reset dada2 --step dada2

# 7. Rerodar taxonomia em todas as amostras
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf --from taxonomy

# 8. Processar projetos diferentes no mesmo banco de dados
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-02.conf
```

### Fluxo recomendado (primeira vez)

```bash
# Passo 1: baixar as sequências
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf --step download

# Passo 2: gerar um manifest por amostra (lista os arquivos .fastq.gz para o QIIME 2)
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf --step manifest

# Passo 3: importar os FASTQs para o formato QIIME 2 (.qza)
#    O QIIME 2 não trabalha com FASTQs diretamente — o import é obrigatório antes de
#    qualquer etapa QIIME 2 (quality, dada2, taxonomy...)
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf --step import

# Passo 4: visualizar qualidade → abre .qzv em view.qiime2.org
#    Analise e ajuste trunc_f/trunc_r no sra_ids_projeto-01.txt se necessário
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf --step quality

# Passo 5: DADA2 (denoising por amostra)
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf --step dada2

# Passo 6: taxonomia, filtro e export
bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-01.conf --from taxonomy
```

> **Nota:** as etapas são independentes por amostra. Se uma amostra falhar no DADA2,
> use `--only <id> --reset dada2 --step dada2` para rerodar apenas ela.

### Estrutura dos resultados

```
results/samples/
├── SRR15247053/
│   ├── qza/
│   │   ├── demux.qza
│   │   ├── demux-summary.qzv
│   │   ├── table.qza
│   │   ├── rep-seqs.qza
│   │   ├── denoising-stats.qza
│   │   └── denoising-stats.qzv
│   ├── taxonomy/
│   │   ├── taxonomy.qza
│   │   └── taxonomy.qzv
│   ├── exports/
│   │   ├── feature-table.tsv   ← tabela de ASVs para R
│   │   ├── sequences.fasta     ← sequências representativas
│   │   └── taxonomy.tsv        ← classificação taxonômica
│   └── reports/
│       ├── 04_dada2.log
│       └── 05_taxonomy.log
└── ERR10890547/
    └── ...
```

---

## Arquivo de Configuração (.conf) — Modo Projeto

Cada projeto tem um `.conf` em `auto-bash/configs/`. Copie o template para criar um novo:

```bash
cp auto-bash/configs/template.conf auto-bash/configs/projeto-03.conf
```

### Parâmetros

```bash
# Nome do projeto
PROJECT_NAME="projeto-01"

# Caminhos
SRA_IDS_FILE="data/manifests/sra_ids_projeto-01.txt"
READS_DIR="data/raw/projeto-01"
MANIFEST="data/manifests/manifest_projeto-01.tsv"
METADATA="data/manifests/metadata_projeto-01.tsv"
OUTDIR="results/projeto-01"
CLASSIFIER="refs/silva-138-99-515-806-nb-classifier.qza"

# Sequenciamento
SEQ_MODE="paired"     # paired ou single

# Parâmetros DADA2
THREADS=16
TRUNC_F=280           # Truncar forward em X bp (definir após ver quality)
TRUNC_R=235           # Truncar reverse em X bp (definir após ver quality)
TRIM_F=0              # Remover primers do início forward (0 se já removidos)
TRIM_R=0              # Remover primers do início reverse (0 se já removidos)
MAX_EE_F=2            # Máximo de erros esperados forward
MAX_EE_R=2            # Máximo de erros esperados reverse
```

### Como definir TRUNC_F e TRUNC_R

1. Rode `--step quality` e abra `demux-summary.qzv` em [view.qiime2.org](https://view.qiime2.org)
2. No gráfico, identifique a posição onde a qualidade **cai abaixo de Q25**
3. Use essa posição como valor de truncamento

**Regra de ouro:** `TRUNC_F + TRUNC_R > tamanho_amplicon + 12bp`

| Região | Amplicon | TRUNC_F sugerido | TRUNC_R sugerido |
|---|---|---|---|
| V4 (515F/806R) | ~253bp | 250–280 | 200–235 |
| V3-V4 (341F/806R) | ~460bp | 260–280 | 220–250 |

### Como definir TRIM_F e TRIM_R

Verifique se os primers estão presentes nas reads:
```bash
zcat data/raw/projeto-01/SRR15247053_1.fastq.gz | head -2 | tail -1
```

- Se o início da read **for o primer** → use o tamanho do primer (ex: `TRIM_F=19` para 515F)
- Se o início da read **for sequência do amplicon** → `TRIM_F=0` (primers já removidos)

Tamanhos dos primers mais comuns:

| Primer | Sequência | Tamanho |
|---|---|---|
| 515F | GTGYCAGCMGCCGCGGTAA | 19bp |
| 806R | GGACTACNVGGGTWTCTAAT | 20bp |
| 341F | CCTACGGGNGGCWGCAG | 17bp |

---

## Arquivo de IDs (sra_ids_projeto-XX.txt)

Formato TSV — cada linha é uma amostra com seus parâmetros DADA2:

```tsv
# sample_id    trunc_f  trunc_r  trim_f  trim_r  max_ee_f  max_ee_r  seq_mode
SRR15247053    280      235      0       0       2         2         paired
ERR10890547    270      240      17      20      2         4         paired
```

- Linhas com `#` são comentários (ignoradas)
- O caminho para este arquivo é definido em `SRA_IDS_FILE` do `.conf`
- No `run_per_sample.sh`, passe o `.conf` — ele localiza o `.txt` automaticamente
- Todas as colunas além de `sample_id` são opcionais: valores ausentes usam os padrões do `.conf`

---

## Validação dos Resultados

Após o DADA2, verifique `denoising-stats.qzv` em [view.qiime2.org](https://view.qiime2.org):

| Coluna | Valor esperado | Se estiver baixo |
|---|---|---|
| `% passed filter` | ≥ 80% | Aumentar `MAX_EE_F` / `MAX_EE_R` |
| `% merged` | ≥ 70% | Aumentar `TRUNC_F`/`TRUNC_R`, verificar primers (`TRIM_F`/`TRIM_R`) |
| `% non-chimeric` | ≥ 80% | Normal ter 5-20% de quimeras |

**Atenção:** se `% merged` estiver próximo de 0%, verifique:
1. `TRUNC_F + TRUNC_R` é maior que o tamanho do amplicon + 12bp?
2. Os primers foram removidos? (`TRIM_F`/`TRIM_R` corretos?)
3. As reads ultrapassam o amplicon? (use `--p-trim-overhang` no script)

---

## Rastreamento de Etapas

Cada projeto/amostra mantém um arquivo `.steps_done` que registra etapas concluídas:

```bash
# Ver etapas concluídas do projeto-01
cat results/projeto-01/.steps_done

# Ver etapas concluídas da amostra SRR15247053
cat results/samples/SRR15247053/.steps_done
```

Etapas já concluídas são **puladas automaticamente** na próxima execução.
Use `--reset ETAPA` para forçar reexecução de uma etapa específica.

---

## Logs

Cada etapa gera um log em `reports/`:

```bash
# Log do DADA2 — projeto
cat results/projeto-01/reports/04_dada2.log

# Log do DADA2 — por amostra
cat results/samples/SRR15247053/reports/04_dada2.log

# Últimas linhas (ver erro)
tail -30 results/projeto-01/reports/04_dada2.log
```
