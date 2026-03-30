#!/usr/bin/env bash
# =============================================================================
# Script 03 - Instalar Java (OpenJDK 17) + Nextflow
# Projeto: Microbioma do Solo (16S rRNA)
# =============================================================================
set -euo pipefail

CONDA_BASE="${HOME}/miniconda3"
NF_ENV="nextflow-env"
NF_BIN="${HOME}/.local/bin"

echo "============================================="
echo "  Instalação do Java + Nextflow"
echo "============================================="

if ! command -v conda &>/dev/null; then
    if [ -f "${CONDA_BASE}/bin/conda" ]; then
        source "${CONDA_BASE}/etc/profile.d/conda.sh"
    else
        echo "[ERRO] Conda não encontrado. Execute primeiro: 01_install_miniconda.sh"
        exit 1
    fi
fi

source "${CONDA_BASE}/etc/profile.d/conda.sh"

# ── Java + Nextflow via conda ─────────────────────────────────────────────────
if conda env list | grep -q "^${NF_ENV}"; then
    echo "[OK] Ambiente ${NF_ENV} já existe."
else
    echo "[1/3] Criando ambiente conda com Java 17 + Nextflow..."
    conda create -n "$NF_ENV" -y -c conda-forge -c bioconda \
        openjdk=17 nextflow
    echo "[OK] Nextflow instalado no ambiente ${NF_ENV}."
fi

# ── Verificação ──────────────────────────────────────────────────────────────
echo "[2/3] Verificando..."
conda run -n "$NF_ENV" java -version 2>&1 | head -1
conda run -n "$NF_ENV" nextflow -version | grep -i version

# ── Docker (instrução manual - requer sudo) ───────────────────────────────────
echo ""
echo "[3/3] ATENÇÃO - Docker requer sudo:"
echo "  Execute manualmente:"
echo "  sudo apt-get update && sudo apt-get install -y docker.io"
echo "  sudo usermod -aG docker \$USER"
echo "  (depois, faça logout e login para aplicar o grupo)"
echo ""
echo "============================================="
echo "  Nextflow instalado!"
echo "  Para usar: conda activate ${NF_ENV}"
echo "  Teste:     nextflow run hello"
echo "============================================="
