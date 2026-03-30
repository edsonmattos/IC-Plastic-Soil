#!/usr/bin/env bash
# =============================================================================
# Script 04 - Baixar classificador Silva 138 (QIIME 2 2024.10)
# Região: 515F-806R (V4)
# =============================================================================
set -euo pipefail

REFS_DIR="$(dirname "$0")/../refs"
mkdir -p "$REFS_DIR"

CLASSIFIER_FILE="${REFS_DIR}/silva-138-99-515-806-nb-classifier.qza"

if [ -f "$CLASSIFIER_FILE" ]; then
    echo "[OK] Classificador Silva já existe: $CLASSIFIER_FILE"
    exit 0
fi

echo "[1/1] Baixando classificador Silva 138 99% - região V4 (515F/806R)..."
echo "      Arquivo ~100MB, pode demorar alguns minutos..."

wget -q --show-progress \
    "https://data.qiime2.org/classifiers/sklearn-1.4.2/silva/silva-138-99-seqs-515-806.qza" \
    -O "${REFS_DIR}/silva-138-99-seqs-515-806.qza"

echo ""
echo "============================================="
echo "  Download concluído!"
echo "  Arquivo: ${CLASSIFIER_FILE}"
echo ""
echo "  ATENÇÃO: Este é o classificador pré-treinado."
echo "  Se necessário treinar para outra região, use:"
echo "  qiime feature-classifier fit-classifier-naive-bayes"
echo "============================================="

# Renomear para o nome esperado pelo pipeline
mv "${REFS_DIR}/silva-138-99-seqs-515-806.qza" "$CLASSIFIER_FILE" 2>/dev/null || true
echo "[OK] Classificador salvo em: $CLASSIFIER_FILE"
