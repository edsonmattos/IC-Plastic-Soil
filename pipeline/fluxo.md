# Fluxo de execução — Pipeline ETL

Guia passo a passo para carregar dados no PostgreSQL.  
Execute todos os comandos a partir da **raiz do projeto** (`projeto-mpb/`).

---

## Primeira vez (setup completo)

```
[1] Banco de dados   →   [2] Venv + deps   →   [3] .env   →   [4] Google Sheets   →   [5] Tabelas
```

### 1. Banco de dados (só na primeira vez)

```bash
sudo -u postgres psql -c "CREATE DATABASE mpb;"
sudo -u postgres psql -c "
  CREATE USER mpb_user WITH PASSWORD 'mpb_pass';
  GRANT ALL PRIVILEGES ON DATABASE mpb TO mpb_user;
  ALTER DATABASE mpb OWNER TO mpb_user;
"
```

### 2. Ambiente virtual e dependências (só na primeira vez)

```bash
python3 -m venv pipeline/venv
pipeline/venv/bin/pip install -r requirements-pipeline.txt
```

### 3. Arquivo `.env`

Editar `pipeline/.env` e preencher:

```env
DATABASE_URL=postgresql://mpb_user:mpb_pass@localhost:5432/mpb
GOOGLE_CREDENTIALS_FILE=/caminho/para/pipeline/chave/arquivo.json
```

Os demais valores (`SPREADSHEET_ID`, `METADATA_SHEET`, `RESULTS_DIR`, etc.) já vêm com o padrão correto.

### 4. Google Sheets — chave da service account

1. Salvar o JSON da service account em `pipeline/chave/`
2. Compartilhar a planilha com o e-mail da service account (papel **Viewer**)

### 5. Criar as tabelas no banco

```bash
pipeline/venv/bin/python -m pipeline init-db
```

Esperado: `Schema applied.`

---

## Uso diário

### Verificar quais projetos serão processados

```bash
pipeline/venv/bin/python -m pipeline list
```

Só aparecem projetos com pasta em `results/`. Projetos que têm `.conf` mas nenhum resultado QIIME são ignorados automaticamente.

---

### Carregar um projeto

```bash
pipeline/venv/bin/python -m pipeline run --project projeto-01
```

**O que acontece internamente:**

```
.conf → dim_project
           ↓
exports/taxonomy.tsv → dim_taxonomy
           ↓
feature-table.tsv → fact_feature_abundance
           ↓
qza/denoising-stats.qza → fact_denoising_stats
           ↓
diversity/*.qza → fact_alpha_diversity
           ↓
Google Sheets → dim_country, dim_polymer, dim_soil_env,
                dim_sample (atualizado), fact_soil_chemistry
```

---

### Carregar todos os projetos de uma vez

```bash
pipeline/venv/bin/python -m pipeline run --all
```

Processa cada projeto com resultados disponíveis e executa o sync com o Google Sheets no final.

---

### Atualizar apenas os dados do Google Sheets

Útil quando a planilha foi editada sem que o QIIME tenha rodado novamente:

```bash
pipeline/venv/bin/python -m pipeline sync-sheets
```

---

### Carregar projetos sem sincronizar o Sheets

```bash
pipeline/venv/bin/python -m pipeline run --all --skip-sheets
pipeline/venv/bin/python -m pipeline run --project projeto-03 --skip-sheets
```

---

## Quando um novo projeto é adicionado

```
1. Rodar o pipeline QIIME até o passo 07_export (gera exports/)
2. Confirmar que results/<projeto>/ existe
3. Preencher a planilha Google Sheets com os metadados das amostras
4. Rodar: pipeline/venv/bin/python -m pipeline run --project <nome>
```

---

## Reprocessar tudo do zero

```bash
# Apaga todas as tabelas (pede confirmação)
pipeline/venv/bin/python -m pipeline drop-db

# Recria o schema
pipeline/venv/bin/python -m pipeline init-db

# Carrega tudo
pipeline/venv/bin/python -m pipeline run --all
```

---

## Solução de problemas

| Sintoma | Causa provável | Solução |
|---|---|---|
| `connection refused` | PostgreSQL parado | `sudo systemctl start postgresql` |
| `role "mpb_user" does not exist` | Usuário não criado | Repetir passo 1 |
| `GOOGLE_CREDENTIALS_FILE not set` | `.env` incompleto | Preencher o caminho do JSON |
| `SpreadsheetNotFound` | Planilha não compartilhada | Compartilhar com o e-mail da service account |
| Projeto não aparece no `list` | Sem pasta em `results/` | Rodar o QIIME até pelo menos o passo 07_export |
| `taxonomy.tsv not found` | Export não gerado | Rodar `--step export` no pipeline QIIME |
| `denoising-stats.qza not found` | DADA2 não concluído | Rodar `--step dada2` no pipeline QIIME |
