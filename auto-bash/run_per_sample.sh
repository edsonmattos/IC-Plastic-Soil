#!/usr/bin/env bash
# =============================================================================
# run_per_sample.sh — Processa cada amostra individualmente (modo banco de dados)
#
# Uso:
#   bash auto-bash/run_per_sample.sh <projeto.conf|samples.txt> [opções]
#
# Opções:
#   --only  AMOSTRA    Processar apenas uma amostra (ex: --only SRR15247053)
#   --step  ETAPA      Rodar apenas uma etapa para todas as amostras
#   --from  ETAPA      Iniciar a partir desta etapa
#   --skip  ETAPA      Pular uma etapa
#   --reset ETAPA      Resetar etapa de todas as amostras
#   --reset-all        Resetar tudo
#   --list             Listar etapas disponíveis
#
# Etapas: download  manifest  import  quality  dada2  taxonomy  filter  export
#
# Resultados:
#   results/samples/<sample_id>/exports/feature-table.tsv
#   results/samples/<sample_id>/exports/sequences.fasta
#   results/samples/<sample_id>/exports/taxonomy.tsv
# =============================================================================
set -euo pipefail

SAMPLES_FILE=""
CONF_THREADS=16
PROJECT_NAME=""
ONLY_SAMPLE=""
ONLY_STEP=""
FROM_STEP=""
SKIP_STEP=""
RESET_STEP=""
RESET_ALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only)      ONLY_SAMPLE="$2"; shift 2 ;;
        --step)      ONLY_STEP="$2";   shift 2 ;;
        --from)      FROM_STEP="$2";   shift 2 ;;
        --skip)      SKIP_STEP="$2";   shift 2 ;;
        --reset)     RESET_STEP="$2";  shift 2 ;;
        --reset-all) RESET_ALL=true;   shift ;;
        --list)
            echo ""
            echo "Etapas disponíveis:"
            echo "  download  → 01 Baixar sequências do SRA/ENA"
            echo "  manifest  → 02 Gerar manifest QIIME 2"
            echo "  import    → 03 Importar FASTQs para .qza"
            echo "  quality   → 03b Visualização de qualidade"
            echo "  dada2     → 04 Denoising com DADA2"
            echo "  taxonomy  → 05 Classificação taxonômica (Silva)"
            echo "  filter    → 06 Filtrar mitocôndrias/cloroplastos"
            echo "  export    → 07 Exportar TSV + FASTA"
            echo ""
            exit 0 ;;
        -*) echo "[ERRO] Opção desconhecida: $1"; exit 1 ;;
        *)  SAMPLES_FILE="$1"; shift ;;
    esac
done

if [ -z "$SAMPLES_FILE" ]; then
    echo "[ERRO] Informe o arquivo de amostras ou config."
    echo "Uso: bash auto-bash/run_per_sample.sh auto-bash/configs/projeto-XX.conf [--step download]"
    exit 1
fi

# Se for .conf, extrai SRA_IDS_FILE e defaults
if [[ "$SAMPLES_FILE" == *.conf ]]; then
    if [ ! -f "$SAMPLES_FILE" ]; then
        echo "[ERRO] Config não encontrada: $SAMPLES_FILE"
        exit 1
    fi
    source "$SAMPLES_FILE"
    CONF_THREADS="${THREADS:-16}"
    SAMPLES_FILE="${SRA_IDS_FILE}"
fi

if [ ! -f "$SAMPLES_FILE" ]; then
    echo "[ERRO] Arquivo não encontrado: $SAMPLES_FILE"
    exit 1
fi

# ── Constantes e caminhos ─────────────────────────────────────────────────────
CLASSIFIER="refs/silva-138-99-515-806-nb-classifier.qza"
CONDA_BASE="${HOME}/miniconda3"
SRA_BIN="${HOME}/miniconda3/envs/sra-tools/bin"
if [ -n "${PROJECT_NAME:-}" ]; then
    RESULTS_BASE="results/${PROJECT_NAME}/samples"
else
    RESULTS_BASE="results/samples"
fi

# ── Cores ─────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${YELLOW}[→]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
hdr()  { echo -e "${CYAN}${BOLD}$1${NC}"; }

# ── Resolver nome curto → ID interno ─────────────────────────────────────────
resolve_step() {
    case "$1" in
        download|01_download)         echo "01_download" ;;
        manifest|02_manifest)         echo "02_manifest" ;;
        import|qiime|03_import)       echo "03_import" ;;
        quality|demux|03b_quality)    echo "03b_quality" ;;
        dada2|04_dada2)               echo "04_dada2" ;;
        taxonomy|silva|05_taxonomy)   echo "05_taxonomy" ;;
        filter|06_filter)             echo "06_filter" ;;
        export|07_export)             echo "07_export" ;;
        *)
            echo "[ERRO] Etapa inválida: '$1'" >&2
            exit 1 ;;
    esac
}

ALL_STEPS=(
    "01_download" "02_manifest" "03_import" "03b_quality"
    "04_dada2" "05_taxonomy" "06_filter" "07_export"
)

# ── Calcular etapas ativas ────────────────────────────────────────────────────
if [ -n "$ONLY_STEP" ]; then
    ACTIVE_STEPS=("$(resolve_step "$ONLY_STEP")")
elif [ -n "$FROM_STEP" ]; then
    ACTIVE_STEPS=()
    found=false
    for s in "${ALL_STEPS[@]}"; do
        [ "$s" = "$(resolve_step "$FROM_STEP")" ] && found=true
        $found && ACTIVE_STEPS+=("$s")
    done
else
    ACTIVE_STEPS=("${ALL_STEPS[@]}")
fi

if [ -n "$SKIP_STEP" ]; then
    SKIP_ID=$(resolve_step "$SKIP_STEP")
    ACTIVE_STEPS=("${ACTIVE_STEPS[@]/$SKIP_ID/}")
fi

# ── Tempo ─────────────────────────────────────────────────────────────────────
_elapsed() {
    local s=$1
    printf "%02dh%02dm%02ds" $((s/3600)) $(( (s%3600)/60 )) $((s%60))
}

_spinner_start() {
    local pid=$1 label="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local start_t=$SECONDS
    while kill -0 "$pid" 2>/dev/null; do
        local i=$(( SECONDS % ${#spin} ))
        printf "\r  ${YELLOW}${spin:$i:1}${NC} %s  [%s]" "$label" "$(_elapsed $(( SECONDS - start_t )))"
        sleep 0.3
    done
    printf "\r%-70s\r" " "
}

# ── Controle de etapas por amostra ────────────────────────────────────────────
_steps_file()  { echo "${RESULTS_BASE}/$1/.steps_done"; }
_step_done()   { grep -q "^$2$" "$(_steps_file "$1")" 2>/dev/null; }
_mark_done()   { echo "$2" >> "$(_steps_file "$1")"; }
_step_active() { [[ " ${ACTIVE_STEPS[*]} " == *" $1 "* ]]; }

_reset_step_sample() {
    local sample="$1" step="$2"
    local outdir="${RESULTS_BASE}/${sample}"
    sed -i "/^${step}$/d" "$(_steps_file "$sample")" 2>/dev/null || true
    case "$step" in
        02_manifest)  rm -f "data/manifests/manifest_${sample}.tsv" ;;
        03_import)    rm -f "${outdir}/qza/demux.qza" ;;
        03b_quality)  rm -f "${outdir}/qza/demux-summary.qzv" ;;
        04_dada2)     rm -f "${outdir}/qza/table.qza" \
                            "${outdir}/qza/rep-seqs.qza" \
                            "${outdir}/qza/denoising-stats.qza" \
                            "${outdir}/qza/denoising-stats.qzv" \
                            "${outdir}/qza/base-transition-stats.qza" ;;
        05_taxonomy)  rm -f "${outdir}/taxonomy/taxonomy.qza" \
                            "${outdir}/taxonomy/taxonomy.qzv" \
                            "${outdir}/taxonomy/rep-seqs-filtered.qza" ;;
        06_filter)    rm -f "${outdir}/qza/table-filtered.qza" \
                            "${outdir}/qza/table-filtered.qzv" ;;
        07_export)    rm -rf "${outdir}/exports/" ;;
    esac
}

# ── Rodar uma etapa com spinner ───────────────────────────────────────────────
run_step() {
    local sample="$1" step_id="$2"; shift 2
    local label="$step_id"
    local LOG="${RESULTS_BASE}/${sample}/reports/${step_id}.log"
    mkdir -p "${RESULTS_BASE}/${sample}/reports"

    if _step_done "$sample" "$step_id"; then
        echo -e "  ${GREEN}[✓]${NC} ${step_id} ${GREEN}(já concluída)${NC}"
        return 0
    fi

    echo -e "  ${YELLOW}[→]${NC} ${step_id}..."
    local start_t=$SECONDS

    "$@" > "$LOG" 2>&1 &
    local bg_pid=$!
    _spinner_start "$bg_pid" "${step_id}"
    wait "$bg_pid"
    local rc=$?

    if [ $rc -eq 0 ]; then
        _mark_done "$sample" "$step_id"
        echo -e "  ${GREEN}[✓]${NC} ${step_id} — $(_elapsed $(( SECONDS - start_t )))"
    else
        echo -e "  ${RED}[✗]${NC} ${step_id} — falhou após $(_elapsed $(( SECONDS - start_t )))"
        echo "     Log: $LOG"
        tail -5 "$LOG" | sed 's/^/     /'
        exit 1
    fi
}

# ── Lê o TSV de amostras ──────────────────────────────────────────────────────
source "${CONDA_BASE}/etc/profile.d/conda.sh"

declare -a SAMPLE_IDS=()
declare -A S_TRUNC_F S_TRUNC_R S_TRIM_F S_TRIM_R S_MAX_EE_F S_MAX_EE_R S_SEQ_MODE S_THREADS

header_read=false
while IFS=$'\t' read -r sample_id trunc_f trunc_r trim_f trim_r max_ee_f max_ee_r seq_mode threads || [ -n "$sample_id" ]; do
    sample_id="${sample_id%%$'\r'}"
    [[ "$sample_id" == "#"* ]] && continue
    [[ "$sample_id" == "sample_id" ]] && continue
    [ -z "$sample_id" ] && continue

    # Filtrar por --only
    if [ -n "$ONLY_SAMPLE" ] && [ "$sample_id" != "$ONLY_SAMPLE" ]; then
        continue
    fi

    SAMPLE_IDS+=("$sample_id")
    S_TRUNC_F["$sample_id"]="${trunc_f:-280}"
    S_TRUNC_R["$sample_id"]="${trunc_r:-235}"
    S_TRIM_F["$sample_id"]="${trim_f:-0}"
    S_TRIM_R["$sample_id"]="${trim_r:-0}"
    S_MAX_EE_F["$sample_id"]="${max_ee_f:-2}"
    S_MAX_EE_R["$sample_id"]="${max_ee_r:-2}"
    S_SEQ_MODE["$sample_id"]="${seq_mode:-paired}"
    S_THREADS["$sample_id"]="${threads:-${CONF_THREADS}}"
done < "$SAMPLES_FILE"

if [ ${#SAMPLE_IDS[@]} -eq 0 ]; then
    err "Nenhuma amostra encontrada em $SAMPLES_FILE"
fi

# ── Cabeçalho ─────────────────────────────────────────────────────────────────
TOTAL_SAMPLES=${#SAMPLE_IDS[@]}
echo ""
hdr "╔══════════════════════════════════════════════════════════╗"
if [ -n "${PROJECT_NAME:-}" ]; then
    hdr "║        Pipeline 16S rRNA — ${PROJECT_NAME}"
else
    hdr "║        Pipeline 16S rRNA — Modo Por Amostra"
fi
hdr "╠══════════════════════════════════════════════════════════╣"
echo -e "║  Amostras:  ${TOTAL_SAMPLES}"
echo -e "║  Etapas:    ${#ACTIVE_STEPS[@]} de ${#ALL_STEPS[@]}"
echo -e "║  Início:    $(date '+%Y-%m-%d %H:%M:%S')"
hdr "╚══════════════════════════════════════════════════════════╝"
echo ""

PIPELINE_START=$SECONDS
sample_num=0

# ═════════════════════════════════════════════════════════════════════════════
# Loop principal — uma amostra por vez
# ═════════════════════════════════════════════════════════════════════════════
for SAMPLE_ID in "${SAMPLE_IDS[@]}"; do
    sample_num=$(( sample_num + 1 ))

    OUTDIR="${RESULTS_BASE}/${SAMPLE_ID}"
    READS_DIR="data/raw/samples/${SAMPLE_ID}"
    MANIFEST="data/manifests/manifest_${SAMPLE_ID}.tsv"
    TRUNC_F="${S_TRUNC_F[$SAMPLE_ID]}"
    TRUNC_R="${S_TRUNC_R[$SAMPLE_ID]}"
    TRIM_F="${S_TRIM_F[$SAMPLE_ID]}"
    TRIM_R="${S_TRIM_R[$SAMPLE_ID]}"
    MAX_EE_F="${S_MAX_EE_F[$SAMPLE_ID]}"
    MAX_EE_R="${S_MAX_EE_R[$SAMPLE_ID]}"
    SEQ_MODE="${S_SEQ_MODE[$SAMPLE_ID]}"
    THREADS="${S_THREADS[$SAMPLE_ID]}"

    mkdir -p "${OUTDIR}/qza" "${OUTDIR}/taxonomy" "${OUTDIR}/exports" "${OUTDIR}/reports"
    touch "$(_steps_file "$SAMPLE_ID")"

    # Resetar se pedido
    if $RESET_ALL; then
        > "$(_steps_file "$SAMPLE_ID")"
    elif [ -n "$RESET_STEP" ]; then
        _reset_step_sample "$SAMPLE_ID" "$(resolve_step "$RESET_STEP")"
    fi

    echo ""
    hdr "┌─ Amostra ${sample_num}/${TOTAL_SAMPLES}: ${SAMPLE_ID}"
    echo -e "│  TRUNC: F=${TRUNC_F} R=${TRUNC_R}  TRIM: F=${TRIM_F} R=${TRIM_R}  MAX_EE: F=${MAX_EE_F} R=${MAX_EE_R}"
    echo    "│"

    # ── 01: Download ──────────────────────────────────────────────────────────
    if _step_active "01_download"; then
        if _step_done "$SAMPLE_ID" "01_download"; then
            echo -e "  ${GREEN}[✓]${NC} 01_download (já concluída)"
        elif ls "${READS_DIR}/${SAMPLE_ID}"*.fastq.gz &>/dev/null 2>&1; then
            echo -e "  ${GREEN}[✓]${NC} 01_download (arquivos já existem)"
            _mark_done "$SAMPLE_ID" "01_download"
        else
            mkdir -p "${READS_DIR}"
            echo -e "  ${YELLOW}[→]${NC} 01_download — ${SAMPLE_ID}..."

            "${SRA_BIN}/prefetch" "${SAMPLE_ID}" \
                --max-size 100g \
                --output-directory "${READS_DIR}" \
                > "${OUTDIR}/reports/01_download.log" 2>&1 &
            prefetch_pid=$!
            while kill -0 "$prefetch_pid" 2>/dev/null; do
                sz=$(du -sh "${READS_DIR}/${SAMPLE_ID}" 2>/dev/null | cut -f1 || echo "0B")
                printf "\r  ⬇  prefetch... %-8s" "$sz"
                sleep 2
            done
            wait "$prefetch_pid" || { echo ""; err "prefetch falhou — veja: ${OUTDIR}/reports/01_download.log"; }
            printf "\r%-50s\r" " "

            "${SRA_BIN}/fasterq-dump" "${READS_DIR}/${SAMPLE_ID}" \
                --outdir "${READS_DIR}" --threads "${THREADS}" --split-files \
                >> "${OUTDIR}/reports/01_download.log" 2>&1

            pigz -p "${THREADS}" "${READS_DIR}/${SAMPLE_ID}"*.fastq \
                >> "${OUTDIR}/reports/01_download.log" 2>&1

            rm -rf "${READS_DIR}/${SAMPLE_ID}"
            _mark_done "$SAMPLE_ID" "01_download"
            echo -e "  ${GREEN}[✓]${NC} 01_download — concluído"
        fi
    fi

    # ── 02: Manifest ─────────────────────────────────────────────────────────
    _do_manifest() {
        conda activate qiime2-amplicon-2026.4
        python3 "$(dirname "$0")/../scripts/build_manifest.py" \
            --reads-dir "${READS_DIR}" \
            --mode "${SEQ_MODE}" \
            --output "${MANIFEST}"
    }
    _step_active "02_manifest" && run_step "$SAMPLE_ID" "02_manifest" _do_manifest

    # ── 03: Import ───────────────────────────────────────────────────────────
    _do_import() {
        conda activate qiime2-amplicon-2026.4
        if [ "${SEQ_MODE}" = "paired" ]; then
            SEQ_TYPE="SampleData[PairedEndSequencesWithQuality]"
            FMT="PairedEndFastqManifestPhred33V2"
        else
            SEQ_TYPE="SampleData[SequencesWithQuality]"
            FMT="SingleEndFastqManifestPhred33V2"
        fi
        qiime tools import \
            --type "${SEQ_TYPE}" \
            --input-path "${MANIFEST}" \
            --input-format "${FMT}" \
            --output-path "${OUTDIR}/qza/demux.qza"
    }
    _step_active "03_import" && run_step "$SAMPLE_ID" "03_import" _do_import

    # ── 03b: Quality ─────────────────────────────────────────────────────────
    _do_quality() {
        conda activate qiime2-amplicon-2026.4
        qiime demux summarize \
            --i-data "${OUTDIR}/qza/demux.qza" \
            --o-visualization "${OUTDIR}/qza/demux-summary.qzv"
    }
    _step_active "03b_quality" && run_step "$SAMPLE_ID" "03b_quality" _do_quality

    # ── 04: DADA2 ────────────────────────────────────────────────────────────
    _do_dada2() {
        conda activate qiime2-amplicon-2026.4
        if [ "${SEQ_MODE}" = "paired" ]; then
            qiime dada2 denoise-paired \
                --i-demultiplexed-seqs "${OUTDIR}/qza/demux.qza" \
                --p-trunc-len-f "${TRUNC_F}" \
                --p-trunc-len-r "${TRUNC_R}" \
                --p-trim-left-f "${TRIM_F}" \
                --p-trim-left-r "${TRIM_R}" \
                --p-max-ee-f "${MAX_EE_F}" \
                --p-max-ee-r "${MAX_EE_R}" \
                --p-n-threads "${THREADS}" \
                --o-table "${OUTDIR}/qza/table.qza" \
                --o-representative-sequences "${OUTDIR}/qza/rep-seqs.qza" \
                --o-denoising-stats "${OUTDIR}/qza/denoising-stats.qza" \
                --o-base-transition-stats "${OUTDIR}/qza/base-transition-stats.qza" \
                --verbose
        else
            qiime dada2 denoise-single \
                --i-demultiplexed-seqs "${OUTDIR}/qza/demux.qza" \
                --p-trunc-len "${TRUNC_F}" \
                --p-trim-left "${TRIM_F}" \
                --p-max-ee "${MAX_EE_F}" \
                --p-n-threads "${THREADS}" \
                --o-table "${OUTDIR}/qza/table.qza" \
                --o-representative-sequences "${OUTDIR}/qza/rep-seqs.qza" \
                --o-denoising-stats "${OUTDIR}/qza/denoising-stats.qza" \
                --o-base-transition-stats "${OUTDIR}/qza/base-transition-stats.qza" \
                --verbose
        fi
        qiime metadata tabulate \
            --m-input-file "${OUTDIR}/qza/denoising-stats.qza" \
            --o-visualization "${OUTDIR}/qza/denoising-stats.qzv"
    }
    _step_active "04_dada2" && run_step "$SAMPLE_ID" "04_dada2" _do_dada2

    # ── 05: Taxonomia ────────────────────────────────────────────────────────
    _do_taxonomy() {
        conda activate qiime2-amplicon-2026.4
        qiime feature-classifier classify-sklearn \
            --i-classifier "${CLASSIFIER}" \
            --i-reads "${OUTDIR}/qza/rep-seqs.qza" \
            --p-n-jobs "${THREADS}" \
            --o-classification "${OUTDIR}/taxonomy/taxonomy.qza"
        qiime metadata tabulate \
            --m-input-file "${OUTDIR}/taxonomy/taxonomy.qza" \
            --o-visualization "${OUTDIR}/taxonomy/taxonomy.qzv"
        qiime taxa filter-seqs \
            --i-sequences "${OUTDIR}/qza/rep-seqs.qza" \
            --i-taxonomy "${OUTDIR}/taxonomy/taxonomy.qza" \
            --p-exclude mitochondria,chloroplast \
            --p-mode contains \
            --o-filtered-sequences "${OUTDIR}/taxonomy/rep-seqs-filtered.qza"
    }
    _step_active "05_taxonomy" && run_step "$SAMPLE_ID" "05_taxonomy" _do_taxonomy

    # ── 06: Filtrar tabela ───────────────────────────────────────────────────
    _do_filter() {
        conda activate qiime2-amplicon-2026.4
        qiime taxa filter-table \
            --i-table "${OUTDIR}/qza/table.qza" \
            --i-taxonomy "${OUTDIR}/taxonomy/taxonomy.qza" \
            --p-exclude mitochondria,chloroplast \
            --p-mode contains \
            --o-filtered-table "${OUTDIR}/qza/table-filtered.qza"
    }
    _step_active "06_filter" && run_step "$SAMPLE_ID" "06_filter" _do_filter

    # ── 07: Export ───────────────────────────────────────────────────────────
    _do_export() {
        conda activate qiime2-amplicon-2026.4
        mkdir -p "${OUTDIR}/exports"
        qiime tools export \
            --input-path "${OUTDIR}/qza/table-filtered.qza" \
            --output-path "${OUTDIR}/exports/feature-table"
        biom convert \
            -i "${OUTDIR}/exports/feature-table/feature-table.biom" \
            -o "${OUTDIR}/exports/feature-table.tsv" \
            --to-tsv
        qiime tools export \
            --input-path "${OUTDIR}/taxonomy/rep-seqs-filtered.qza" \
            --output-path "${OUTDIR}/exports"
        mv "${OUTDIR}/exports/dna-sequences.fasta" "${OUTDIR}/exports/sequences.fasta"
        qiime tools export \
            --input-path "${OUTDIR}/taxonomy/taxonomy.qza" \
            --output-path "${OUTDIR}/exports"
    }
    _step_active "07_export" && run_step "$SAMPLE_ID" "07_export" _do_export

    echo -e "└─ ${GREEN}[✓] ${SAMPLE_ID} concluído${NC}"
done

# ── Resumo final ──────────────────────────────────────────────────────────────
TOTAL_ELAPSED=$(_elapsed $(( SECONDS - PIPELINE_START )))
echo ""
hdr "╔══════════════════════════════════════════════════════════╗"
echo -e "║  ${GREEN}✓ Concluído: ${sample_num}/${TOTAL_SAMPLES} amostras${NC}"
echo    "║"
echo    "║  Resultados: results/samples/<sample_id>/exports/"
echo -e "║  Tempo total: ${TOTAL_ELAPSED}"
hdr "╚══════════════════════════════════════════════════════════╝"
echo ""
