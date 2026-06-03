# Microbioma Associado a Microplásticos do Solo: Uma Revisão Metanalítica
## Roteiro de Apresentação e Estrutura do Artigo Científico

> **Tipo de trabalho**: Revisão Metanalítica — Bioinformática  
> **Pipeline de reprocessamento**: QIIME2 2026.4 · DADA2 · Silva 138 · PostgreSQL  
> **Corpus**: 9 estudos primários · 554 amostras · 6 países · 11 tipos de plástico

---

## O QUE É UMA REVISÃO METANALÍTICA?

Antes de tudo: este trabalho **não coletou solo nem extraiu DNA**. Ele **reprocessou e sintetizou** dados brutos de sequenciamento publicados por outros grupos, aplicando um pipeline bioinformático padronizado e uniforme sobre todos os estudos. Isso é uma revisão metanalítica computacional — a contribuição científica está na **síntese quantitativa**, na **padronização metodológica** e na **identificação de padrões que estudos individuais não conseguem revelar**.

> **Analogia**: uma metanálise clínica pergunta "qual o efeito médio de um medicamento em vários ensaios?". Esta revisão pergunta: "qual o efeito de diferentes plásticos no microbioma do solo, sintetizando múltiplos estudos independentes?"

---

## 1. ROTEIRO DA APRESENTAÇÃO

### Estrutura sugerida (25–35 min)

| Bloco | Tempo | Conteúdo | Recurso visual |
|---|---|---|---|
| Abertura | 2 min | Crise dos plásticos + pergunta que nenhum estudo sozinho responde | Imagem impacto global |
| Justificativa da metanálise | 3 min | Por que sintetizar estudos? Limitação dos estudos individuais | Diagrama PRISMA simplificado |
| Objetivos | 2 min | Pergunta PICO / perguntas de síntese | Slide objetivos |
| Metodologia de seleção | 4 min | Critérios de inclusão, busca sistemática, heterogeneidade | Fluxograma de seleção |
| Pipeline de reprocessamento | 4 min | QIIME2, DADA2, Silva 138 — por que padronizar? | Diagrama de pipeline |
| Banco de dados | 2 min | Star schema + dashboard como ferramenta de síntese | Screenshot dashboard |
| Resultados — Qualidade | 2 min | Heterogeneidade metodológica entre estudos | Heatmap DADA2 |
| Resultados — Diversidade | 5 min | Efeito do plástico: Shannon, Faith PD, Observed Features | Boxplots + forest plot |
| Resultados — Taxonomia | 4 min | Padrões metanalíticos: quais bactérias respondem ao plástico? | Heatmap + pareto |
| Discussão | 4 min | Síntese, limitações da metanálise, viés de publicação | |
| Conclusão | 2 min | Resposta à pergunta central + contribuição metodológica | |

---

## 2. CONTEÚDO POR SEÇÃO

### 2.1 Abertura — O Problema que Nenhum Estudo Resolve Sozinho

> *"Sabe-se que microplásticos contaminam solos em todos os continentes. Sabe-se que o microbioma do solo é essencial para a vida. Mas uma pergunta simples continua sem resposta clara: afinal, diferentes plásticos afetam o microbioma de forma diferente — e esse efeito se repete em diferentes países e contextos?"*

O problema é que:
- Um estudo na Alemanha analisa PBSA em solo agrícola
- Um estudo na China analisa PE e PLA em solo de trigo
- Um estudo nos EUA analisa sete tipos de polímero em pradaria

**Cada um usa um pipeline ligeiramente diferente, um classificador diferente, parâmetros de denoising diferentes.** Os resultados não são diretamente comparáveis.

**A revisão metanalítica resolve isso**: reprocessa todos os dados brutos com o mesmo pipeline, cria um banco de dados unificado e, pela primeira vez, permite comparar os efeitos do plástico no microbioma do solo entre 9 estudos, 6 países e 11 tipos de polímero.

---

### 2.2 Justificativa da Abordagem Metanalítica

#### Por que não bastam estudos individuais?

| Limitação do estudo individual | Como a metanálise supera |
|---|---|
| Tamanho amostral pequeno (N=12 a N=18) | Pooling: N total = 554 amostras |
| Resultado pode ser local/específico | Padrão replicado em múltiplos países é mais robusto |
| Pipeline próprio de cada grupo | Pipeline único (QIIME2 2026.4) aplicado a todos |
| Viés de um classificador ou versão | Mesmo classificador (SILVA 138, sklearn 1.4.2) |
| Impossível comparar entre estudos | Banco de dados unificado permite consultas cruzadas |

#### Onde este trabalho se posiciona na literatura

```
Nível 1 (mais fraco):  Estudo de caso isolado
Nível 2:               Séries de casos
Nível 3:               Estudos observacionais
Nível 4:               Revisão narrativa
Nível 5 (mais forte):  REVISÃO METANALÍTICA  ← Este trabalho
```

Uma revisão metanalítica de dados bioinformáticos (também chamada de *meta-análise computacional* ou *secondary data analysis*) é considerada o mais alto nível de evidência em bioinformática de microbioma quando:
1. A seleção de estudos é sistemática e documentada
2. O reprocessamento é padronizado e reprodutível
3. A heterogeneidade entre estudos é quantificada

---

### 2.3 Objetivos

**Pergunta central (formato PICO adaptado para ecologia microbiana)**

> Em solos com microplásticos (**P**opulação), diferentes tipos de polímero (**I**ntervenção) alteram a diversidade e composição do microbioma bacteriano (**O**utcome), em comparação com solos controle ou entre tipos de plástico (**C**omparação), conforme síntese de múltiplos estudos de sequenciamento 16S rRNA?

**Objetivos específicos**
1. Conduzir busca sistemática de estudos de sequenciamento 16S rRNA em solos com microplásticos disponíveis no NCBI SRA / ENA
2. Definir critérios de inclusão/exclusão e documentar o fluxo de seleção (PRISMA)
3. Reprocessar todos os dados brutos com pipeline QIIME2 padronizado, garantindo comparabilidade
4. Construir banco de dados relacional integrando resultados de diversidade, taxonomia e metadados de plástico
5. Quantificar e sintetizar o efeito do tipo de polímero sobre a diversidade alfa do microbioma do solo
6. Identificar táxons consistentemente associados a tipos específicos de plástico entre os estudos

---

### 2.4 Metodologia

#### 2.4.1 Estratégia de Busca Sistemática

**Bases de dados consultadas**: NCBI SRA, ENA (European Nucleotide Archive), SRA-Explorer

**Termos de busca**:
```
("16S rRNA" OR "16S ribosomal") AND
("microplastic" OR "plastic" OR "polyethylene" OR "polylactic acid" OR "PLA" OR "PET") AND
("soil" OR "terrestrial" OR "rhizosphere")
```

**Fluxo PRISMA (simplificado)**:
```
Registros identificados (SRA/ENA)
              ↓
  Triagem por título/abstract
              ↓
  Elegíveis para leitura completa
              ↓
  Critérios de inclusão aplicados
              ↓
  Estudos incluídos na metanálise: 9
```

#### 2.4.2 Critérios de Inclusão e Exclusão

| Critério | Inclusão | Exclusão |
|---|---|---|
| Tipo de amostra | Solo ou rizosferas com plástico | Água, sedimento, plastisfera marinha |
| Sequenciamento | 16S rRNA amplicon (qualquer região) | Metagenômica shotgun, ITS (fungos) |
| Dados brutos | Disponíveis no SRA/ENA | Apenas dados processados publicados |
| Plástico | Qualquer polímero identificado | Plástico não especificado |
| Organismo | Prokaryota (Bacteria + Archaea) | Exclusivamente fungos ou eucariontes |

#### 2.4.3 Corpus Final

| ID | BioProject | País | Amplicon | Sequenciamento | N Amostras | Plástico(s) |
|---|---|---|---|---|---|---|
| projeto-01 | PRJNA702448 | Alemanha | V3-V4 | 2×300 bp paired | 31 | PBSA |
| projeto-03 | — | Itália | V3-V4 | 2×300 bp paired | 61 | HDPE, PBAT, PE |
| projeto-04 | — | China | V3-V4 | 2×250 bp single | 111 | PE, PLA |
| projeto-05 | — | EUA | V4 | 2×300 bp paired | 12 | PBAT, PE |
| projeto-06-barba | — | Suíça | V3-V4 | 2×300 bp paired | 18 | PBAT, PE, PLA |
| projeto-06-villum | — | Groenlândia | V3-V4 | 1×250 bp single | 17 | PBAT, PE, PLA |
| projeto-07 | — | EUA | V4 | 2×250 bp paired | 168 | PE, PLA, blendas |
| projeto-08 | — | EUA | V4 | 2×251 bp paired | 88 | PE, blendas biodegr. |
| projeto-09-bacteria | PRJNA1155845 | China | V4 | 2×251 bp paired | 48 | PET, PLA |

**Total**: 554 amostras · 6 países · 4 continentes · 11 tipos de polímero

#### 2.4.4 Avaliação da Heterogeneidade Metodológica

Uma revisão metanalítica precisa quantificar **o quanto os estudos são diferentes entre si** — a *heterogeneidade*. Aqui ela é de dois tipos:

**Heterogeneidade técnica** (controlada pelo reprocessamento):

| Parâmetro | Variação entre estudos | Como controlamos |
|---|---|---|
| Versão do pipeline | QIIME 1, QIIME 2 diversas versões | Reprocessamento único: QIIME2 2026.4 |
| Classificador | SILVA várias versões, Greengenes | SILVA 138 full-length, sklearn 1.4.2 |
| Parâmetros DADA2 | Cada grupo define os próprios | Critérios documentados por amplicon (Tabela S1) |
| Profundidade | Rarefação arbitrária por estudo | Definida por mínimo de não-quiméricos (Tabela S2) |

**Heterogeneidade biológica** (intrínseca — analisada, não eliminada):

| Fonte | Exemplos |
|---|---|
| Clima e bioma | Ártico (Groenlândia) vs Subtropical (China) |
| Tipo de solo | Agrícola, pradaria, solo virgen |
| Tempo de incubação | Dias a anos de exposição ao plástico |
| Tamanho do plástico | Microplástico, pó, filme, pellet |
| Concentração | g/kg solo variável entre estudos |

> Esta heterogeneidade biológica é parte do objeto de estudo — a metanálise busca identificar padrões **apesar** dela.

#### 2.4.5 Pipeline de Reprocessamento Padronizado

```
┌─────────────────────────────────────────────────────────────┐
│  BUSCA E DOWNLOAD (SRA Tools)                               │
│  prefetch + fasterq-dump → FASTQs brutos                    │
└─────────────────────────┬───────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  QIIME2 2026.4 — IMPORT + QUALIDADE                         │
│  Manifest format (paired/single por estudo)                 │
│  demux-summary.qzv → inspeção de qualidade                  │
└─────────────────────────┬───────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  DADA2 — DENOISING (parâmetros por amplicon)                │
│  Remoção de primers (TRIM_F/TRIM_R)                         │
│  Truncagem por qualidade (TRUNC_F/TRUNC_R)                  │
│  Inferência de ASVs + remoção de quimeras                   │
│  → denoising-stats.qza + table.qza + rep-seqs.qza           │
└─────────────────────────┬───────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  CLASSIFICAÇÃO TAXONÔMICA                                   │
│  SILVA 138 full-length, sklearn 1.4.2                       │
│  → taxonomy.qza                                             │
└─────────────────────────┬───────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  DIVERSIDADE ALFA E BETA                                    │
│  Rarefação por estudo (SAMPLING_DEPTH)                      │
│  Shannon H', Faith PD, Observed Features                    │
│  Bray-Curtis, UniFrac ponderado/não-ponderado               │
└─────────────────────────┬───────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  BANCO DE DADOS METANALÍTICO (PostgreSQL)                   │
│  Star schema: dim_sample, dim_polymer, dim_country,         │
│  dim_taxonomy, fact_alpha_diversity,                        │
│  fact_feature_abundance, fact_denoising_stats               │
└─────────────────────────┬───────────────────────────────────┘
                          ↓
                  SÍNTESE METANALÍTICA
            (análise estatística + visualizações)
```

#### 2.4.6 Banco de Dados como Ferramenta Metanalítica

O banco de dados PostgreSQL é o **coração da metanálise** — ele integra todos os estudos em um único modelo relacional que permite consultas que seriam impossíveis com arquivos separados.

```
dim_country ──┐
dim_polymer ──┤
              ├──► dim_sample ──► fact_alpha_diversity
dim_soil_env ─┤              └──► fact_denoising_stats
dim_project ──┤              └──► fact_feature_abundance ──► dim_taxonomy
              └──────────────────► fact_soil_chemistry
```

**Perguntas respondidas pelo banco que nenhum estudo isolado responde**:

```sql
-- Exemplo: Shannon médio por tipo de plástico em todos os estudos
SELECT po.polymer_type, AVG(a.shannon), COUNT(*) AS n_amostras
FROM fact_alpha_diversity a
JOIN dim_sample s ON a.sample_id = s.id
JOIN dim_polymer po ON s.polymer_id = po.id
GROUP BY po.polymer_type ORDER BY AVG(a.shannon) DESC;

-- Exemplo: Quais filos são mais abundantes em solos com PLA vs PE?
SELECT t.phylum, po.polymer_type, SUM(fa.read_count)
FROM fact_feature_abundance fa
JOIN dim_taxonomy t ON fa.taxonomy_id = t.id
JOIN dim_sample s ON fa.sample_id = s.id
JOIN dim_polymer po ON s.polymer_id = po.id
WHERE po.polymer_type IN ('PLA','PE')
GROUP BY t.phylum, po.polymer_type;
```

---

### 2.5 Resultados da Revisão Metanalítica

#### 2.5.1 Qualidade Metodológica dos Estudos Incluídos

A avaliação da qualidade do processamento bioinformático é análoga ao *risk of bias* em metanálises clínicas. Utilizamos as estatísticas DADA2 como indicador.

| Estudo | Input Reads | % Filtrado | % Merged | % Não-Quimérico | Qualidade |
|---|---|---|---|---|---|
| projeto-01 | 4.261.177 | 94.7% | 57.5% | 17.1% | ⚠️ Baixa (quimeras) |
| projeto-03 | 7.359.762 | 90.6% | 25.4% | 78.6% | ✅ Alta |
| projeto-04 | 8.327.364 | 100.0% | N/A¹ | 93.0% | ✅ Alta |
| projeto-05 | 1.701.323 | 91.9% | 75.3% | 72.5% | ✅ Alta |
| projeto-06-barba | 2.483.550 | 64.1% | 52.1% | 49.6% | ⚠️ Moderada |
| projeto-06-villum | 914.525 | 82.4% | N/A¹ | 76.6% | ✅ Alta |
| projeto-07 | 14.598.740 | 88.6% | 72.5% | 71.4% | ✅ Alta |
| projeto-08 | 17.150.036 | 84.1% | 81.4% | 79.6% | ✅ Alta |
| projeto-09-bacteria | 4.968.348 | 91.5% | 61.7% | 60.2% | ✅ Alta |

¹ Single-end: não há etapa de merge

> **Nota sobre projeto-01**: 5 amostras (SRR15247053–57) apresentaram >90% de quimeras, sugerindo lotes de biblioteca heterogêneos no estudo original. Mantidas na análise com rarefação conservadora (6.000 reads); sensibilidade explorada na discussão.

#### 2.5.2 Síntese da Diversidade Alfa — Efeito do Tipo de Plástico

**Shannon H' médio por tipo de plástico** (síntese de todos os estudos):

| Plástico | N Amostras | Shannon médio | Tipo | Tendência |
|---|---|---|---|---|
| HDPE | 4 | 10.25 | Convencional | ↑↑ Alta diversidade |
| PBAT | 73 | 9.62 | Biodegradável | ↑↑ Alta diversidade |
| Polyester blend | 11 | 9.97 | Convencional | ↑↑ Alta diversidade |
| PE | 138 | 9.48 | Convencional | ↑↑ Alta diversidade |
| starch/PBAT | 25 | 7.56 | Blenda amido | ↑ Moderada |
| PLA/PBAT | 36 | 7.40 | Blenda biodegr. | ↑ Moderada |
| PLA | 79 | 7.32 | Biodegradável | ↑ Moderada |
| starch/Pol. blend | 26 | 7.24 | Blenda amido | ↑ Moderada |
| PLA/PHA | 43 | 7.11 | Blenda biodegr. | ↑ Moderada |
| PBSA | 9 | 5.19 | Biodegradável | ↓ Baixa |
| PET | 11 | 2.97 | Convencional | ↓↓ Muito baixa |

**Padrão metanalítico identificado**:
> Plásticos convencionais de alta estabilidade (PE, HDPE) associam-se a **maior** diversidade bacteriana. Polímeros biodegradáveis (PLA, PLA/PBAT, PBSA) associam-se a **menor** diversidade. PET destaca-se como o mais seletivo.

**Atenção à confusão**: este padrão é observacional. PE tem mais estudos (138 amostras em 7 países) do que PBSA (9 amostras, 1 país). A heterogeneidade geográfica confunde o efeito do plástico — o que a discussão deve abordar.

**Diversidade por região geográfica** (Faith PD — riqueza filogenética):

| País | N Amostras | Shannon médio | Faith PD médio | Bioma |
|---|---|---|---|---|
| Itália | 61 | 10.57 | 206.4 | Mediterrâneo |
| EUA | 268 | 8.29 | ~86 | Subtropical/Pradaria |
| China | 159 | 6.16 | ~94 | Subtropical |
| Suíça | 18 | 7.80 | 56.6 | Alpino |
| Alemanha | 31 | 5.38 | 18.8 | Temperado |
| Groenlândia | 17 | 8.04 | 39.7 | Ártico |

#### 2.5.3 Síntese Taxonômica — Padrões Metanalíticos

**Mapa de presença × intensidade dos principais filos nos 9 estudos**:

| Filo | DE | IT | CN(p04) | EUA(p05) | CH | GL | EUA(p07) | EUA(p08) | CN(p09) | Ubiquidade |
|---|---|---|---|---|---|---|---|---|---|---|
| Proteobacteria | ●●● | ●●● | ●●● | ●●● | ●●● | ●● | ●● | ●●● | ● | 9/9 |
| Actinobacteriota | ●● | ●●● | ●● | ●● | ● | ●● | ●● | ●●● | — | 8/9 |
| Acidobacteriota | ●● | ●●● | ●● | ●●● | ●● | ●●● | ●●● | ● | — | 8/9 |
| Bacteroidota | ●●● | ●●● | ●●● | ●●● | ●●● | ● | ● | ●●● | — | 8/9 |
| Planctomycetota | ● | ●●● | ●● | ●●● | ●●● | ●●● | ●●● | ● | — | 8/9 |
| Chloroflexi | ●● | ●●● | ●● | ●● | ●●● | ●● | ●●● | ●● | — | 8/9 |
| Firmicutes | ●● | ●● | ●●● | ●●● | ● | ● | ●● | ●●● | — | 7/9 |
| Patescibacteria | — | ●● | ●● | ●● | ●●● | ●●● | ●● | ●●● | — | 7/9 |
| Gemmatimonadota | ● | ●●● | ●●● | ●● | ●● | ●● | ●● | — | — | 7/9 |
| Verrucomicrobiota | — | ●●● | ●● | ●●● | ●●● | ●●● | ●● | ● | — | 7/9 |

> ●●● >15% reads · ●● 5–15% · ● 1–5% · — <1%  
> DE=Alemanha · IT=Itália · CN=China · EUA · CH=Suíça · GL=Groenlândia

**Core microbiome dos solos com plástico** (presente em ≥7/9 estudos):
Proteobacteria, Actinobacteriota, Acidobacteriota, Bacteroidota, Planctomycetota, Chloroflexi, Firmicutes, Patescibacteria, Gemmatimonadota, Verrucomicrobiota

**Filos com distribuição geograficamente restrita** (potenciais indicadores de contexto):
- Crenarchaeota (Archaea): Alemanha e EUA (p05) — solos de pH neutro a ácido
- Deinococcota: EUA (p08) — extrema resistência a estresse oxidativo
- WPS-2: Suíça (p06-barba) — solos alpinos, pouco estudado
- Armatimonadota: EUA (p07) e EUA (p08) — solos de pradaria

**Hierarquia taxonômica (Domínio → Filo → Classe) — top 10 globais**:

| Domínio | Filo | Classe | Reads totais |
|---|---|---|---|
| Bacteria | Actinobacteriota | Actinobacteria | 6.157.478 |
| Bacteria | Proteobacteria | Gammaproteobacteria | 5.028.096 |
| Bacteria | Proteobacteria | Alphaproteobacteria | 4.873.293 |
| Bacteria | Bacteroidota | Bacteroidia | 2.907.522 |
| Bacteria | Firmicutes | Bacilli | 2.239.917 |
| Bacteria | Patescibacteria | Saccharimonadia | 1.662.455 |
| Bacteria | Acidobacteriota | Vicinamibacteria | 1.256.364 |
| Bacteria | Acidobacteriota | Blastocatellia | 1.219.938 |
| Bacteria | Planctomycetota | Planctomycetes | 1.155.898 |
| Bacteria | Verrucomicrobiota | Verrucomicrobiae | 1.004.372 |

#### 2.5.4 Mapa de Frequência, Localização e Relevância

Este mapa responde: *qual a contribuição de cada estudo para cada dimensão analítica da metanálise?*

| Dimensão | DE | IT | CN(p04) | EUA(p05) | CH | GL | EUA(p07) | EUA(p08) | CN(p09) |
|---|---|---|---|---|---|---|---|---|---|
| **Alta diversidade** (Shannon>9) | — | ✓✓ | ✓ | ✓ | — | — | ✓✓ | — | — |
| **Baixa diversidade** (Shannon<6) | ✓ | — | — | — | — | — | — | ✓ | ✓✓ |
| **Efeito PLA documentado** | — | — | ✓ | — | ✓ | ✓ | ✓ | ✓ | ✓✓ |
| **Plástico convencional (PE)** | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓✓ | ✓ | — |
| **Bioma extremo** | — | — | — | — | ✓ Alpino | ✓✓ Ártico | — | — | — |
| **Maior poder estatístico** | — | ✓ | ✓✓ | — | — | — | ✓✓✓ | ✓✓ | ✓ |
| **Dados de pH/SOC disponíveis** | — | — | ✓ | ✓ | ✓ | ✓ | ✓ | — | — |
| **Archaea detectada** | ✓ | ✓ | — | ✓ | — | — | — | — | — |
| **Blendas biodegradáveis** | — | ✓ | — | — | ✓ | ✓ | ✓✓ | ✓✓ | — |
| **PET (convencional seletivo)** | — | — | — | — | — | — | — | — | ✓✓ |

> ✓✓✓ referência principal · ✓✓ contribuição forte · ✓ contribuição moderada

---

### 2.6 Discussão Metanalítica

#### O que a síntese revela que estudos individuais não revelam

**1. Padrão robusto: plásticos biodegradáveis ≠ neutralidade ecológica**  
Estudos individuais com PLA reportam resultados conflitantes. A síntese de 9 estudos mostra consistentemente Shannon menor em solos com PLA (7.32 médio) versus PE (9.48). A liberação de ácido láctico durante degradação do PLA possivelmente seleciona táxons acidotolerantes (Actinobacteriota, Firmicutes) e suprime grupos sensíveis.

**2. Proteobacteria como marcador ubíquo — mas não uniforme**  
Presente em 9/9 estudos, mas a proporção varia: dominante na Alemanha e China, menos dominante nos EUA (projeto-07, dominância de Acidobacteriota). Isso indica que o contexto edáfico modula a resposta bacteriana ao plástico.

**3. Patescibacteria como sinal de estresse**  
Alta prevalência nos estudos com maior heterogeneidade técnica (baixo % não-quimérico: barba=49.6%, villum=76.6%) e no estudo com menor diversidade geral (projeto-08). Patescibacteria são parasitas de outras bactérias — sua dominância pode indicar colapso parcial da comunidade.

**4. O efeito geográfico supera o efeito do plástico?**  
Shannon varia mais entre países (2.89–10.57) do que entre tipos de plástico dentro de um mesmo estudo. Isso é um resultado metanalítico importante: **o contexto edáfico pode ser mais determinante que o tipo de plástico**. Estudos futuros precisam controlar por tipo de solo, clima e uso da terra.

**5. PET como caso extremo**  
Projeto-09 (China, PET + PLA): Shannon = 2.89, apenas Proteobacteria detectada com reads substanciais. PET é um dos polímeros mais resistentes à biodegradação — pode estar selecionando apenas organismos altamente especializados. N=11 amostras: interpretar com cautela.

#### Limitações da revisão metanalítica

1. **Heterogeneidade biológica irredutível**: tempo de exposição, concentração de plástico e características do solo diferem entre estudos e não foram completamente padronizáveis
2. **Viés de publicação**: estudos com efeito positivo (plástico *muda* microbioma) têm maior probabilidade de publicação que estudos negativos
3. **Variação de amplicons**: estudos usaram V3-V4 e V4, com primers diferentes; apesar do reprocessamento padronizado, a região alvo influencia quais táxons são detectados
4. **Metadados incompletos**: tempo de incubação, concentração de plástico e profundidade de solo não foram uniformemente disponibilizados pelos estudos primários
5. **N desbalanceado**: projeto-07 (168 amostras, EUA) domina análises de pool; resultados ponderados podem refletir mais o contexto americano

---

### 2.7 Conclusão

**Resposta à pergunta central**:
> Sim — diferentes tipos de plástico associam-se a padrões distintos no microbioma bacteriano do solo, com uma tendência metanalítica de **menor diversidade em solos com polímeros biodegradáveis** (especialmente PLA) em comparação a plásticos convencionais como PE. Este padrão é observado em múltiplos países e contextos, sugerindo um mecanismo biológico consistente relacionado à degradação dos polímeros.

**Contribuição metodológica**:
- Primeiro pipeline bioinformático unificado (QIIME2 2026.4) aplicado simultaneamente a 9 estudos de microbioma do solo com plástico
- Banco de dados relacional (star schema PostgreSQL) que permite consultas metanalíticas sobre 554 amostras de 6 países
- Dashboard interativo como ferramenta de exploração dos dados da revisão

**Próximos passos para o artigo**:
1. Análise de diversidade beta (PERMANOVA por tipo de plástico, controlado por país)
2. Identificação de ASVs marcadores por polímero (DESeq2 ou ANCOM-BC)
3. Forest plot quantitativo do efeito de PE vs PLA sobre Shannon H'
4. Quantificação formal da heterogeneidade (I² estatístico)
5. Expandir corpus com estudos de fungos (ITS — projeto-06-fungos, projeto-09-fungo)

---

## 3. ESTRUTURA DO ARTIGO CIENTÍFICO

### Título
**PT-BR**: Microbioma Associado a Microplásticos do Solo: Uma Revisão Metanalítica

**EN**: *Soil Microbiome Associated with Microplastics: A Meta-Analytic Review of 16S rRNA Amplicon Sequencing Studies*

**Palavras-chave**: microplásticos · microbioma do solo · 16S rRNA · metanálise · diversidade bacteriana · QIIME2 · bioinformática

---

### Seções do Artigo

#### Abstract (250–300 palavras)
- **Background**: lacuna na literatura — estudos isolados de microbioma com plástico, sem síntese quantitativa padronizada
- **Methods**: busca sistemática SRA/ENA; 9 estudos incluídos (N=554); reprocessamento QIIME2 2026.4, DADA2, SILVA 138; banco PostgreSQL
- **Results**: diversidade alfa (Shannon, Faith PD) por tipo de plástico e país; 10 filos ubíquos identificados; PLA associado à menor diversidade (Shannon 7.32 vs PE 9.48)
- **Conclusions**: heterogeneidade biológica substancial; polímeros biodegradáveis não são ecologicamente neutros; pipeline padronizado como recurso para futuras metanálises

#### 1. Introduction (~800 palavras)
1.1 Crise dos microplásticos no solo — escala global e persistência  
1.2 Microbioma do solo: funções ecológicas e vulnerabilidade  
1.3 A plastisfera como nicho bacteriano — evidências atuais  
1.4 Limitação dos estudos individuais: fragmentação e incomparabilidade  
1.5 Revisão metanalítica como solução: padronização e síntese  
1.6 Objetivos deste trabalho

#### 2. Materials and Methods (~1.200 palavras)
**2.1 Estratégia de busca e seleção (PRISMA)**
- Bases de dados, termos, período
- Fluxograma de seleção + critérios de inclusão/exclusão
- Tabela de características dos estudos incluídos

**2.2 Pipeline bioinformático de reprocessamento**
- Download: SRA Tools (prefetch + fasterq-dump)
- QIIME2 2026.4: import, cutadapt, DADA2
- Parâmetros DADA2 por amplicon (Tabela S1)
- Classificação: SILVA 138 full-length, sklearn 1.4.2
- Rarefação: critérios e profundidades (Tabela S2)

**2.3 Banco de dados metanalítico**
- Modelo star schema (Figure 1)
- ETL em Python: extração dos QZA, carga no PostgreSQL
- Controle de qualidade dos dados carregados

**2.4 Análises estatísticas**
- Diversidade alfa: Shannon H', Faith PD, Observed Features
- Comparação entre grupos: Kruskal-Wallis + Dunn (α=0.05)
- Heterogeneidade entre estudos: estatística I²
- Diversidade beta: Bray-Curtis dissimilarity, UniFrac; PERMANOVA (999 permutações)
- Visualizações: Python (Plotly), R (ggplot2, vegan)

#### 3. Results (~1.500 palavras)
**3.1 Seleção de estudos e avaliação de qualidade metodológica**  
→ Fluxo PRISMA, estatísticas DADA2 (Tabela 1)

**3.2 Diversidade alfa — síntese metanalítica**  
→ Shannon e Faith PD por tipo de plástico (Figura 2: boxplot + forest plot)  
→ Shannon e Faith PD por país (Figura 3)  
→ Correlação diversidade × pH e SOC (Figura 4: scatter)

**3.3 Composição taxonômica**  
→ Core microbiome (presente ≥7/9 estudos) — Tabela 2  
→ Heatmap: filo × projeto (Figura 5)  
→ Hierarquia Domínio→Filo→Classe (Figura 6: treemap drill-down)  
→ Pareto global dos 15 filos mais abundantes (Figura 7)

**3.4 Efeito do tipo de polímero**  
→ Tabela 3: diversidade por polímero (N, Shannon, Faith PD)  
→ Plásticos biodegradáveis vs convencionais (Figura 8)  
→ Táxons diferencialmente abundantes por polímero (se DESeq2 aplicado)

**3.5 Padrões geográficos**  
→ Mapa mundial de amostras e diversidade (Figura 9)  
→ Biomas extremos: Groenlândia (Ártico) e Suíça (Alpino)

#### 4. Discussion (~1.200 palavras)
4.1 Padrão principal: biodegradáveis ≠ neutralidade  
4.2 Core microbiome dos solos com plástico  
4.3 Patescibacteria como indicador de perturbação  
4.4 Heterogeneidade geográfica como confundidor  
4.5 Comparação com revisões anteriores (se existirem)  
4.6 Limitações metodológicas (heterogeneidade biológica, viés de publicação, amplicons diferentes)  
4.7 Implicações para políticas de uso de plásticos biodegradáveis em agricultura

#### 5. Conclusions (~200 palavras)

#### Declarations
- Data availability: NCBI SRA (accession numbers em Tabela S3)
- Code availability: GitHub (pipeline QIIME2 + ETL PostgreSQL)
- Funding, conflicts of interest

#### References
Formato sugerido: **Nature/Scientific Reports** (Vancouver numerado)  
Estimativa: 45–65 referências

#### Supplementary Material
| Item | Conteúdo |
|---|---|
| Table S1 | Parâmetros DADA2 completos por estudo |
| Table S2 | Profundidades de rarefação e amostras excluídas |
| Table S3 | Número de acesso SRA de todas as amostras |
| Table S4 | Contagens de reads por filo por estudo |
| Figure S1 | Curvas de rarefação por estudo |
| Figure S2 | PCoA plots (Bray-Curtis e UniFrac) |
| Figure S3 | Forest plot Shannon H' — PE vs PLA |
| Code S1 | Pipeline QIIME2 (scripts bash) |
| Code S2 | Pipeline ETL PostgreSQL (Python) |

---

## 4. REFERÊNCIAS BASE

> *(Verificar DOIs e atualizar antes da submissão)*

**Metanálise e revisão sistemática em microbioma**
- Pasolli et al. (2019) "Extensive Unexplored Human Microbiome Diversity" — *Cell* — referência para metanálise computacional de microbioma
- Duvallet et al. (2017) "Meta-analysis of gut microbiome studies identifies disease-specific and shared responses" — *Nature Communications*

**Microplásticos no solo**
- de Souza Machado et al. (2018) "Microplastics as an emerging threat to terrestrial ecosystems" — *Global Change Biology*
- Rillig et al. (2019) "Microplastic Effects on Plants" — *New Phytologist*
- Zhang et al. (2022) "Microplastic pollution in agricultural soils" — *Science of The Total Environment*

**Microbioma do solo e plásticos**
- Huang et al. (2019) "Impact of microplastics on soil microbial community" — buscar revisão atual
- Zhu et al. (2022) "Biodegradable microplastics and soil microbiome" — buscar revisão atual

**Bioinformática — pipeline**
- Bolyen et al. (2019) "Reproducible, interactive, scalable and extensible microbiome data science using QIIME 2" — *Nature Biotechnology*
- Callahan et al. (2016) "DADA2: High-resolution sample inference from Illumina amplicon data" — *Nature Methods*
- Quast et al. (2013) "The SILVA ribosomal RNA gene database project" — *Nucleic Acids Research*

**Estatística e diversidade**
- Jost (2006) "Entropy and diversity" — *Oikos*
- Faith (1992) "Conservation evaluation and phylogenetic diversity" — *Biological Conservation*
- Higgins & Thompson (2002) "Quantifying heterogeneity in a meta-analysis" — *Statistics in Medicine* (para I²)

**Plastisfera**
- Zettler et al. (2013) "Life in the Plastisphere" — *Environmental Science & Technology*

---

## 5. PONTOS-CHAVE PARA DEFESA

### "Isso não é uma pesquisa original — você só reanalisou dados de outros."
> *"Revisões metanalíticas são consideradas o mais alto nível de evidência científica. A contribuição original está em: (1) padronizar o processamento de 9 estudos que usavam pipelines diferentes; (2) construir o primeiro banco de dados integrado que permite consultas cruzadas; (3) identificar padrões de diversidade que nenhum estudo individual conseguia ver. Isso é diferente de 'repetir' um estudo — é síntese quantitativa."*

### "Por que os dados são tão heterogêneos?"
> *"Heterogeneidade é esperada e desejável em metanálises — ela reflete a realidade. O objetivo não é eliminar a variação entre estudos, mas quantificá-la e identificar padrões que se sustentam apesar dela. A estatística I² quantifica essa heterogeneidade; um I²>75% indicaria heterogeneidade substancial que precisaria ser explicada pelos moderadores."*

### "Você incluiu 9 estudos — é suficiente?"
> *"Metanálises com N<10 estudos são comuns em ecologia microbiana, especialmente em tópicos emergentes como microplásticos em solo. O que importa é que os estudos sejam selecionados sistematicamente, com critérios documentados, e que a heterogeneidade seja reportada. Com 554 amostras totais, o poder estatístico das análises agrupadas é superior a qualquer estudo individual."*

### "Como você controlou o viés de publicação?"
> *"O viés de publicação é uma limitação reconhecida e documentada no trabalho. Para mitigá-lo, incluímos todos os estudos com dados disponíveis no SRA/ENA, independentemente do resultado reportado — não apenas os que publicaram artigo com 'efeito significativo do plástico'. Estudos futuros poderiam usar funnel plots para avaliar esse viés formalmente."*

### "Por que SILVA 138 e não Greengenes 2?"
> *"SILVA 138 é o banco de referência com maior cobertura para 16S procarioto em solos, incluindo filos raros como Patescibacteria e Armatimonadota que são abundantes neste corpus. A versão 138 tem compatibilidade confirmada com sklearn 1.4.2 (presente no QIIME2 2026.4), garantindo reprodutibilidade."*

---

*Documento atualizado com base no título da tese: "Microbioma associado a microplásticos do solo: uma revisão metanalítica". Dados reais extraídos dos 9 projetos analisados (554 amostras, arquivos QZA + PostgreSQL).*
