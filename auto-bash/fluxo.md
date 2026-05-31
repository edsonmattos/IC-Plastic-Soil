# Fluxo completo — Pipeline 16S rRNA (QIIME 2)

Arquivo de configuração do projeto: `auto-bash/configs/projeto-03.conf`

---

## Etapa 1 — Download

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --step download
```

---

## Etapa 2 — Manifest único do projeto

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --reset manifest --step manifest
```

Gera `data/manifests/manifest_projeto-03.tsv` com todas as amostras do projeto.

---

## Etapa 3 — Import

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --reset import --step import
```

Importa todos os FASTQs em um único `results/projeto-03/qza/demux.qza`.

---

## Etapa 4 — Visualização de qualidade

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --reset quality --step quality
```

Abre `results/projeto-03/qza/demux-summary.qzv` no [view.qiime2.org](https://view.qiime2.org) e anota
a posição onde a qualidade (mediana) cai abaixo de Q25–Q28 no forward e no reverse.

---

## Etapa 5 — Ajustar parâmetros de corte no conf

```bash
# auto-bash/configs/projeto-03.conf
TRUNC_F=240        # posição de corte forward (antes dos Ns / queda de qualidade)
TRUNC_R=180        # posição de corte reverse
SAMPLING_DEPTH=9000  # ajustar após ver o denoising-stats.qzv
```

Regra de sobreposição mínima para V4 (amplicon ~253 bp):
```
TRUNC_F + TRUNC_R > 253 + 20 = 273 bp
```

---

## Etapa 6 — DADA2

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --step dada2
```

Abre `results/projeto-03/qza/denoising-stats.qzv` e verifica:
- **% input passed filter** → deve ser > 85%
- **% input merged** → deve ser > 60% (para a maioria das amostras)
- **% input non-chimeric** → deve ser > 50%

Se precisar ajustar os parâmetros, edita o conf e re-roda:

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --reset dada2 --step dada2
```

---

## Etapa 7 — Taxonomy + filtro + export

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --from taxonomy
```

Roda em sequência:
- **05 taxonomy** — classifica ASVs com o classificador Silva 138
- **06 filter** — remove mitocôndrias e cloroplastos
- **07 export** — exporta para `results/projeto-03/exports/`:
  - `feature-table.tsv`
  - `sequences.fasta`
  - `taxonomy.tsv`

---

## Etapa 8 — Barplot taxonômico

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --step barplot
```

Abre `results/projeto-03/qzv/taxa-barplot.qzv` no [view.qiime2.org](https://view.qiime2.org).
Permite visualizar a composição taxonômica por amostra em diferentes níveis (filo, classe, ordem, família, gênero).

---

## Etapa 9 — Árvore filogenética

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --step tree
```

Constrói a árvore filogenética com MAFFT + FastTree a partir dos ASVs filtrados.
Necessária para as métricas de diversidade que usam distâncias filogenéticas (UniFrac, Faith's PD).

---

## Etapa 10 — Métricas de diversidade alfa + beta

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --step diversity
```

Gera em `results/projeto-03/diversity/`:

| Métrica | Tipo | Descrição |
|---|---|---|
| Shannon | Alfa | Riqueza + equitabilidade |
| Faith's PD | Alfa | Diversidade filogenética |
| Observed features | Alfa | Número de ASVs |
| Bray-Curtis | Beta | Dissimilaridade por abundância |
| Jaccard | Beta | Dissimilaridade por presença/ausência |
| UniFrac (weighted) | Beta | Beta filogenética ponderada |
| UniFrac (unweighted) | Beta | Beta filogenética binária |

Os plots PCoA (Emperor) podem ser abertos no [view.qiime2.org](https://view.qiime2.org).

> **Atenção:** `SAMPLING_DEPTH` no conf define a profundidade de rarefação.
> Amostras com menos reads que esse valor são excluídas da análise.

---

## Etapa 11 — Curva de rarefação

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-03.conf --step rarefaction
```

Abre `results/projeto-03/qzv/alpha-rarefaction.qzv` no [view.qiime2.org](https://view.qiime2.org).
Confirma se o `SAMPLING_DEPTH` está em uma região de platô (diversidade estabilizada).

---

## Fluxo recomendado para projetos novos

```bash
# 1. Roda do início até o quality (gera manifest + metadata automaticamente)
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --from manifest --step quality

# 2. Ajusta TRUNC_F, TRUNC_R, SAMPLING_DEPTH no conf após ver o demux-summary.qzv

# 3. Roda o DADA2
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --step dada2

# 4. Verifica denoising-stats.qzv — se precisar ajustar parâmetros:
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --reset dada2 --step dada2

# 5. Quando DADA2 estiver aprovado, roda o restante
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --from taxonomy
```

> **Importante:** sempre rode `--step manifest` antes de qualquer outra etapa em projetos novos.
> O manifest gera o metadata automaticamente — sem ele, o pipeline quebra no filter.

---

## Rodar tudo de uma vez

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf
```

## Retomar de onde parou

```bash
bash auto-bash/run_pipeline.sh auto-bash/configs/projeto-XX.conf --from <etapa>
```

Quando usar cada opção:
```bash
--from manifest      # projeto novo ou FASTQs mudaram
--from dada2         # ajustou TRUNC_F/R ou MAX_EE no conf
--from taxonomy      # DADA2 aprovado, quer rodar o restante
--from filter        # taxonomy já feita, erro no filter ou barplot
--from barplot       # taxonomy e filter ok, só quer gerar visualizações
```

## Listar etapas disponíveis

```bash
bash auto-bash/run_pipeline.sh --list
```
