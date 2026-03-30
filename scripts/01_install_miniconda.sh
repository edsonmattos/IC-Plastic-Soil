#!/usr/bin/env bash
# =============================================================================
# Script 01 - Instalar Miniconda
# Projeto: Microbioma do Solo (16S rRNA)
# =============================================================================
set -euo pipefail

MINICONDA_DIR="$HOME/miniconda3"
INSTALLER="/tmp/miniconda_installer.sh"

echo "============================================="
echo "  Instalação do Miniconda"
echo "============================================="

if [ -d "$MINICONDA_DIR" ]; then
    echo "[OK] Miniconda já está instalado em $MINICONDA_DIR"
    exit 0
fi

echo "[1/3] Baixando Miniconda..."
wget -q --show-progress \
    "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" \
    -O "$INSTALLER"

echo "[2/3] Instalando Miniconda em $MINICONDA_DIR ..."
bash "$INSTALLER" -b -p "$MINICONDA_DIR"
rm -f "$INSTALLER"

echo "[3/3] Inicializando conda no shell..."
"$MINICONDA_DIR/bin/conda" init bash

# Adiciona ao PATH da sessão atual
export PATH="$MINICONDA_DIR/bin:$PATH"

conda config --set auto_activate_base false

echo ""
echo "============================================="
echo "  Miniconda instalado com sucesso!"
echo "  Reinicie o terminal ou execute:"
echo "  source ~/.bashrc"
echo "============================================="
