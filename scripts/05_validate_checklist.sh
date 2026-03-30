#!/usr/bin/env bash
# =============================================================================
# Script 05 - Checklist de Validação do Pipeline
# Projeto: Microbioma do Solo (16S rRNA)
# =============================================================================

RESULTS="${1:-results}"
CONDA_BASE="${HOME}/miniconda3"
QIIME_ENV="qiime2-amplicon-2026.4"

if [ -f "${CONDA_BASE}/etc/profile.d/conda.sh" ]; then
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
    conda activate "$QIIME_ENV" 2>/dev/null || true
fi

pass() { echo -e "  [✓] $1"; }
warn() { echo -e "  [!] $1"; }
fail() { echo -e "  [✗] $1"; }

echo "============================================="
echo "  Checklist de Validação - Microbioma 16S"
echo "============================================="
echo ""

# ── 1. Qualidade dos metadados ─────────────────────────────────────────────
echo "1. Qualidade dos metadados"
METADATA="${RESULTS}/../data/manifests/metadata.tsv"
if [ -f "$METADATA" ]; then
    INVALID=$(grep -P '[\s!@#$%^&*()+=\[\]{};:'"'"'",<>?/\\|`~]' "$METADATA" \
              | grep -v "^#" | wc -l || true)
    if [ "$INVALID" -eq 0 ]; then
        pass "Nenhum caractere especial encontrado nos metadados."
    else
        warn "$INVALID linha(s) com possíveis caracteres especiais. Verifique manualmente."
    fi
else
    warn "Arquivo de metadados não encontrado: $METADATA"
fi

# ── 2. Arquivos QZV gerados ────────────────────────────────────────────────
echo ""
echo "2. Arquivos de visualização (.qzv)"
for qzv in \
    "${RESULTS}/qza/demux-summary.qzv" \
    "${RESULTS}/qza/denoising-stats.qzv" \
    "${RESULTS}/taxonomy/taxonomy.qzv" \
    "${RESULTS}/qza/table-filtered.qzv"
do
    if [ -f "$qzv" ]; then
        pass "$(basename $qzv)"
    else
        fail "$(basename $qzv) - NÃO ENCONTRADO"
    fi
done
echo "  → Abra em: https://view.qiime2.org"

# ── 3. Estatísticas de denoising ──────────────────────────────────────────
echo ""
echo "3. Estatísticas de Denoising (DADA2)"
STATS="${RESULTS}/qza/denoising-stats.qza"
if [ -f "$STATS" ]; then
    TMP=$(mktemp -d)
    qiime tools export --input-path "$STATS" --output-path "$TMP" 2>/dev/null
    if [ -f "${TMP}/stats.tsv" ]; then
        # Calcula média de reads que passaram
        AVG_PASS=$(awk -F'\t' 'NR>1 && $1!="#" {
            gsub(/%/,"",$NF); sum+=$NF; n++
        } END { if(n>0) printf "%.1f", sum/n }' "${TMP}/stats.tsv" 2>/dev/null || echo "N/A")

        if [ "$AVG_PASS" != "N/A" ]; then
            PCT=${AVG_PASS%.*}
            if [ "$PCT" -ge 70 ]; then
                pass "Média de reads que passaram: ${AVG_PASS}% (ideal ≥70%)"
            elif [ "$PCT" -ge 50 ]; then
                warn "Média de reads que passaram: ${AVG_PASS}% - abaixo do ideal (≥70%)"
                warn "  → Revisar parâmetros trunc_f/trunc_r e max_ee"
            else
                fail "Média de reads que passaram: ${AVG_PASS}% - muito baixo!"
                fail "  → Revisar urgentemente os pontos de corte"
            fi
        fi
    fi
    rm -rf "$TMP"
else
    warn "Arquivo de estatísticas não encontrado ainda."
fi

# ── 4. Tabela de ASVs ─────────────────────────────────────────────────────
echo ""
echo "4. Tabela de ASVs"
TABLE_TSV="${RESULTS}/exports/feature-table.tsv"
if [ -f "$TABLE_TSV" ]; then
    N_ASVS=$(grep -c "^[^#]" "$TABLE_TSV" 2>/dev/null || echo 0)
    pass "Tabela de ASVs: ${N_ASVS} features (excl. header)"
else
    fail "feature-table.tsv não encontrado"
fi

# ── 5. FASTA de sequências representativas ────────────────────────────────
echo ""
echo "5. Sequências representativas"
FASTA="${RESULTS}/exports/sequences.fasta"
if [ -f "$FASTA" ]; then
    N_SEQS=$(grep -c "^>" "$FASTA" 2>/dev/null || echo 0)
    pass "sequences.fasta: ${N_SEQS} sequências"
else
    fail "sequences.fasta não encontrado"
fi

# ── 6. Taxonomia ──────────────────────────────────────────────────────────
echo ""
echo "6. Taxonomia"
TAX_TSV="${RESULTS}/exports/taxonomy.tsv"
if [ -f "$TAX_TSV" ]; then
    N_CLASSIFIED=$(awk -F'\t' 'NR>1 && $2!="" && $2!="Unassigned" {n++} END {print n}' "$TAX_TSV")
    TOTAL=$(awk 'NR>1' "$TAX_TSV" | wc -l)
    PCT=$(awk "BEGIN {printf \"%.1f\", ${N_CLASSIFIED}/${TOTAL}*100}" 2>/dev/null || echo "N/A")
    pass "Classificação taxonômica: ${N_CLASSIFIED}/${TOTAL} features (${PCT}%)"
else
    fail "taxonomy.tsv não encontrado"
fi

# ── 7. Paralelização ──────────────────────────────────────────────────────
echo ""
echo "7. Configuração de threads"
NF_THREADS=$(grep "threads" nextflow.config 2>/dev/null | grep -v "//" | head -1 || echo "?")
NPROC=$(nproc)
pass "CPUs disponíveis: ${NPROC}"
echo "  → Threads configuradas no nextflow.config: $(echo $NF_THREADS | tr -d ' ')"

echo ""
echo "============================================="
echo "  Checklist concluído!"
echo "============================================="
