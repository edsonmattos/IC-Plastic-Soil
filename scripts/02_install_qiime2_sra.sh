#!/usr/bin/env bash
# =============================================================================
# Script 02 - Instalar QIIME 2 (2024.10) + SRA Toolkit
# Projeto: Microbioma do Solo (16S rRNA)
# =============================================================================
set -euo pipefail

CONDA_BASE="${HOME}/miniconda3"
QIIME_ENV="qiime2-amplicon-2026.4"

echo "============================================="
echo "  Instalação do QIIME 2 + SRA Toolkit"
echo "============================================="

# Verifica se conda está disponível
if ! command -v conda &>/dev/null; then
    if [ -f "${CONDA_BASE}/bin/conda" ]; then
        source "${CONDA_BASE}/etc/profile.d/conda.sh"
    else
        echo "[ERRO] Conda não encontrado. Execute primeiro: 01_install_miniconda.sh"
        exit 1
    fi
fi

source "${CONDA_BASE}/etc/profile.d/conda.sh"

# ── QIIME 2 ──────────────────────────────────────────────────────────────────
if conda env list | grep -q "^${QIIME_ENV}"; then
    echo "[OK] Ambiente ${QIIME_ENV} já existe."
else
    echo "[1/4] Baixando arquivo de ambiente QIIME 2 2024.10..."
    QIIME_YML="/tmp/qiime2-amplicon-2024.10-environment-linux-conda.yml"
    wget -q --show-progress \
        "https://data.qiime2.org/distro/amplicon/qiime2-amplicon-ubuntu-latest-conda.yml" \
        -O "$QIIME_YML"

    echo "[2/4] Criando ambiente conda: ${QIIME_ENV} (pode levar ~20 min)..."
    mamba env create -n "$QIIME_ENV" --file "$QIIME_YML"
    rm -f "$QIIME_YML"
    echo "[OK] QIIME 2 instalado."
fi

# ── SRA Toolkit ──────────────────────────────────────────────────────────────
echo "[3/4] Instalando SRA Toolkit no ambiente ${QIIME_ENV}..."
conda run -n "$QIIME_ENV" conda install -y -c bioconda sra-tools 2>/dev/null || \
    conda install -n "$QIIME_ENV" -y -c bioconda sra-tools

# ── Verificação ──────────────────────────────────────────────────────────────
echo "[4/4] Verificando instalação..."
conda activate "$QIIME_ENV"
echo "  QIIME 2: $(qiime --version)"
echo "  prefetch: $(prefetch --version 2>&1 | head -1)"

echo ""
echo "============================================="
echo "  Instalação concluída!"
echo "  Para ativar: conda activate ${QIIME_ENV}"
echo "============================================="
