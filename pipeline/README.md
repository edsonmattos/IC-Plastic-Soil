# Pipeline MPB — ETL para PostgreSQL

Aplicação Python que carrega os resultados do pipeline QIIME2 (taxonomia, abundância, diversidade) e os metadados da planilha Google Sheets para um banco de dados PostgreSQL em modelo estrela (star schema).

---

## Pré-requisitos

| Dependência | Versão mínima |
|---|---|
| Python | 3.10+ |
| PostgreSQL | 14+ (instalado localmente) |
| Banco `mpb` criado | ver [Configuração do banco](#configuração-do-banco) |
| Service account Google | ver [Google Sheets](#google-sheets) |

---

## Estrutura da pasta

```
pipeline/
  .env                        ← variáveis de ambiente (não vai para o git)
  chave/
    pipeline-ic-*.json        ← chave da service account Google
  venv/                       ← ambiente virtual Python (não vai para o git)
  config.py                   ← lê .env e define caminhos
  db/
    schema.sql                ← DDL completo (dims + facts)
    connection.py             ← conexão psycopg2
    migrations.py             ← create_tables() / drop_all_tables()
  extractors/
    conf_reader.py            ← lê arquivos .conf do pipeline QIIME
    qiime_reader.py           ← lê taxonomy.tsv, feature-table.tsv e QZAs
    sheets_reader.py          ← lê Google Sheets via service account
  loaders/
    dimensions.py             ← upsert nas tabelas dim_*
    facts.py                  ← upsert nas tabelas fact_*
  pipeline.py                 ← orquestrador (load_project / sync_sheets)
  main.py                     ← CLI (comandos click)
  __main__.py                 ← permite `python -m pipeline`
```

---

## Instalação

```bash
# 1. Criar o ambiente virtual (já feito se venv/ existe)
python3 -m venv pipeline/venv

# 2. Instalar dependências
pipeline/venv/bin/pip install -r requirements-pipeline.txt
```

---

## Configuração do banco

Execute uma vez como root/sudo:

```bash
sudo -u postgres psql -c "CREATE DATABASE mpb;"
sudo -u postgres psql -c "
  CREATE USER mpb_user WITH PASSWORD 'mpb_pass';
  GRANT ALL PRIVILEGES ON DATABASE mpb TO mpb_user;
  ALTER DATABASE mpb OWNER TO mpb_user;
"
```

Teste a conexão:

```bash
psql "postgresql://mpb_user:mpb_pass@localhost:5432/mpb" -c "SELECT version();"
```

---

## Google Sheets

A planilha usa autenticação por **service account** (sem precisar de browser).

**Passos para criar a chave:**

1. Acesse [console.cloud.google.com](https://console.cloud.google.com/)
2. Crie (ou selecione) um projeto
3. Ative as APIs: **Google Sheets API** e **Google Drive API**
4. Vá em **IAM & Admin → Service Accounts → Create Service Account**
5. Baixe o JSON da chave e salve em `pipeline/chave/`
6. Compartilhe a planilha com o e-mail da service account (papel **Leitor/Viewer**)

---

## Arquivo `.env`

O arquivo `pipeline/.env` centraliza toda a configuração:

```env
# Banco de dados
DATABASE_URL=postgresql://mpb_user:mpb_pass@localhost:5432/mpb

# Google Sheets
GOOGLE_CREDENTIALS_FILE=/caminho/absoluto/pipeline/chave/arquivo.json
SPREADSHEET_ID=162p_HpQWQt6OYtroJY_0uXuO3-WnVste8Mnd4YXGg10
METADATA_SHEET=Metadata - Bacteria

# Caminhos relativos à raiz do projeto (os defaults já estão corretos)
RESULTS_DIR=results
CONFIGS_DIR=auto-bash/configs
DATA_DIR=data
```

---

## Como usar

Todos os comandos são executados a partir da **raiz do projeto**:

```bash
# Ativar o venv (opcional — pode usar o caminho direto)
source pipeline/venv/bin/activate

# Ou chamar diretamente sem ativar:
PYTHON=pipeline/venv/bin/python
```

### Criar as tabelas (primeira vez)

```bash
pipeline/venv/bin/python -m pipeline init-db
```

### Ver projetos disponíveis

Lista apenas os projetos que têm pasta correspondente em `results/`:

```bash
pipeline/venv/bin/python -m pipeline list
```

### Carregar um projeto específico

```bash
pipeline/venv/bin/python -m pipeline run --project projeto-01
```

### Carregar múltiplos projetos

```bash
pipeline/venv/bin/python -m pipeline run --project projeto-01 --project projeto-02
```

### Carregar todos os projetos + sincronizar Sheets

```bash
pipeline/venv/bin/python -m pipeline run --all
```

### Carregar projetos sem sincronizar o Sheets

```bash
pipeline/venv/bin/python -m pipeline run --all --skip-sheets
```

### Sincronizar apenas o Google Sheets

Atualiza dimensões e fatos de química do solo sem reprocessar os arquivos QIIME:

```bash
pipeline/venv/bin/python -m pipeline sync-sheets
```

### Recriar todas as tabelas (apaga tudo)

```bash
pipeline/venv/bin/python -m pipeline drop-db
pipeline/venv/bin/python -m pipeline init-db
```

---

## Modelo de dados

```
                        ┌──────────────┐
                        │  dim_project │
                        └──────┬───────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
   ┌──────┴──────┐      ┌──────┴──────┐     ┌──────┴──────┐
   │ dim_country │      │ dim_polymer │     │ dim_soil_env│
   └──────┬──────┘      └──────┬──────┘     └──────┬──────┘
          │                    │                    │
          └────────────────────┼────────────────────┘
                               │
                        ┌──────┴──────┐
                        │  dim_sample │
                        └──────┬──────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
┌─────────┴────────┐  ┌────────┴──────┐  ┌─────────┴────────┐
│ fact_feature_    │  │ fact_denoising│  │ fact_alpha_      │
│ abundance        │  │ _stats        │  │ diversity        │
└──────────────────┘  └───────────────┘  └──────────────────┘
          │
┌─────────┴────────┐  ┌───────────────┐
│ dim_taxonomy     │  │ fact_soil_    │
│                  │  │ chemistry     │
└──────────────────┘  └───────────────┘
```

### Dimensões

| Tabela | Fonte | Descrição |
|---|---|---|
| `dim_project` | `.conf` files | Parâmetros DADA2, modo de sequenciamento |
| `dim_taxonomy` | `exports/taxonomy.tsv` | 7 níveis taxonômicos (domínio → espécie) |
| `dim_country` | Google Sheets | País e clima |
| `dim_polymer` | Google Sheets | Tipo, formato, cor, biodegradabilidade do plástico |
| `dim_soil_env` | Google Sheets | Solo, cultivar, tipo de experimento, manejo |
| `dim_sample` | Manifests + Sheets | Amostra (SRR/ERR), links para todas as dims |

### Fatos

| Tabela | Fonte | Granularidade |
|---|---|---|
| `fact_feature_abundance` | `exports/feature-table.tsv` | 1 linha por (amostra × ASV) |
| `fact_denoising_stats` | `qza/denoising-stats.qza` | 1 linha por amostra |
| `fact_alpha_diversity` | `diversity/*.qza` | 1 linha por amostra (Shannon, Faith PD, evenness, observed features) |
| `fact_soil_chemistry` | Google Sheets | 1 linha por amostra (pH, SOC, TN, NH4, etc.) |

---

## Consultas úteis (exemplos)

```sql
-- Abundância por filo em cada projeto
SELECT p.name AS projeto, t.phylum, SUM(f.read_count) AS total_reads
FROM fact_feature_abundance f
JOIN dim_taxonomy t  ON t.id = f.taxonomy_id
JOIN dim_project  p  ON p.id = f.project_id
WHERE t.phylum IS NOT NULL
GROUP BY p.name, t.phylum
ORDER BY p.name, total_reads DESC;

-- Diversidade por país
SELECT c.country, AVG(d.shannon) AS shannon_medio, AVG(d.faith_pd) AS faith_pd_medio
FROM fact_alpha_diversity d
JOIN dim_sample  s ON s.id = d.sample_id
JOIN dim_country c ON c.id = s.country_id
GROUP BY c.country
ORDER BY shannon_medio DESC;

-- Amostras por tipo de plástico e solo
SELECT po.polymer_type, se.soil_type, COUNT(*) AS n_amostras
FROM dim_sample s
JOIN dim_polymer  po ON po.id = s.polymer_id
JOIN dim_soil_env se ON se.id = s.soil_env_id
GROUP BY po.polymer_type, se.soil_type
ORDER BY n_amostras DESC;
```
