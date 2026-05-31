#!/usr/bin/env bash
# =============================================================================
# Script 04 - Baixar classificador Silva 138 (QIIME 2 2024.10)
# Região: 515F-806R (V4)
# =============================================================================
set -euo pipefail

REFS_DIR="$(dirname "$0")/../refs"
mkdir -p "$REFS_DIR"

CLASSIFIER_FILE="${REFS_DIR}/silva-138-99-515-806-nb-classifier.qza"

if [ -s "$CLASSIFIER_FILE" ]; then
    echo "[OK] Classificador Silva já existe: $CLASSIFIER_FILE"
    exit 0
fi
rm -f "$CLASSIFIER_FILE"

echo "[1/2] Tentando classificador V4 (515F/806R) — sklearn 1.4.2..."
wget --show-progress \
    "https://data.qiime2.org/classifiers/sklearn-1.4.2/silva/silva-138-99-seqs-515-806-nb-classifier.qza" \
    -O "${CLASSIFIER_FILE}" || true

if [ ! -s "${CLASSIFIER_FILE}" ]; then
    echo "[!] URL V4 não disponível — baixando classificador full-length (~1 GB)..."
    rm -f "${CLASSIFIER_FILE}"
    wget --show-progress \
        "https://data.qiime2.org/classifiers/sklearn-1.4.2/silva/silva-138-99-nb-classifier.qza" \
        -O "${CLASSIFIER_FILE}" || true
fi

if [ ! -s "${CLASSIFIER_FILE}" ]; then
    echo "[ERRO] Ambos os downloads falharam. Verifique a conexão e tente novamente."
    rm -f "${CLASSIFIER_FILE}"
    exit 1
fi

echo ""
echo "============================================="
echo "  Download concluído!"
echo "  Arquivo: ${CLASSIFIER_FILE}"
echo "============================================="
echo "[OK] Classificador salvo em: $CLASSIFIER_FILE"
