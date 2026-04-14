#!/usr/bin/env bash
# =============================================================================
# run_pipeline.sh — Pipeline 16S rRNA (QIIME 2 direto, sem Nextflow)
#
# Uso:
#   bash auto-bash/run_pipeline.sh <config.conf> [opções]
#
# Opções:
#   --step  ETAPA      Rodar apenas uma etapa (ex: --step dada2)
#   --from  ETAPA      Iniciar a partir desta etapa (ex: --from taxonomy)
#   --skip  ETAPA      Pular uma etapa (ex: --skip download)
#   --reset ETAPA      Resetar etapa para forçar reexecução
#   --reset-all        Resetar todas as etapas
#   --list             Listar etapas disponíveis
#
# Etapas (nome curto):
#   download  manifest  import  dada2  taxonomy  filter  export
# =============================================================================
set -euo pipefail

# ── Parse de argumentos ───────────────────────────────────────────────────────
CONF=""
ONLY_STEP=""
FROM_STEP=""
SKIP_STEP=""
RESET_STEP=""
RESET_ALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --step)   ONLY_STEP="$2";  shift 2 ;;
        --from)   FROM_STEP="$2";  shift 2 ;;
        --skip)   SKIP_STEP="$2";  shift 2 ;;
        --reset)  RESET_STEP="$2"; shift 2 ;;
        --reset-all) RESET_ALL=true; shift ;;
        --list)
            echo ""
            echo "Etapas disponíveis:"
            echo "  download  → 01 Baixar sequências do SRA"
            echo "  manifest  → 02 Gerar manifest QIIME 2"
            echo "  import    → 03 Importar FASTQs para .qza"
            echo "  quality   → 03b Visualização de qualidade (demux-summary.qzv)"
            echo "  dada2     → 04 Denoising com DADA2"
            echo "  taxonomy  → 05 Classificação taxonômica (Silva)"
            echo "  filter    → 06 Filtrar mitocôndrias/cloroplastos"
            echo "  export    → 07 Exportar TSV + FASTA para R"
            echo ""
            exit 0 ;;
        -*) echo "[ERRO] Opção desconhecida: $1"; exit 1 ;;
        *)  CONF="$1"; shift ;;
    esac
done

if [ -z "$CONF" ]; then
    echo "[ERRO] Informe o arquivo de configuração."
    echo "Uso: bash auto-bash/run_pipeline.sh <config.conf> [--step dada2]"
    exit 1
fi

if [ ! -f "$CONF" ]; then
    echo "[ERRO] Configuração não encontrada: $CONF"
    echo "Crie com: cp auto-bash/configs/template.conf auto-bash/configs/meu-projeto.conf"
    exit 1
fi

source "$CONF"

# ── Resolver nome curto → ID interno ─────────────────────────────────────────
resolve_step() {
    case "$1" in
        download|01_download_sra)    echo "01_download_sra" ;;
        manifest|02_build_manifest)  echo "02_build_manifest" ;;
        import|qiime|03_qiime_import) echo "03_qiime_import" ;;
        quality|demux|summary|03b_demux_summary) echo "03b_demux_summary" ;;
        dada2|04_dada2)              echo "04_dada2" ;;
        taxonomy|silva|05_taxonomy)  echo "05_taxonomy" ;;
        filter|06_filter_table)      echo "06_filter_table" ;;
        export|07_export)            echo "07_export" ;;
        *)
            echo "[ERRO] Etapa inválida: '$1'" >&2
            echo "       Opções: download manifest import dada2 taxonomy filter export" >&2
            exit 1 ;;
    esac
}

# ── Cores e símbolos ──────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m';  BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${YELLOW}[→]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
hdr()  { echo -e "${CYAN}${BOLD}$1${NC}"; }

# ── Tempo decorrido ───────────────────────────────────────────────────────────
_elapsed() {
    local s=$1
    printf "%02dh%02dm%02ds" $((s/3600)) $(( (s%3600)/60 )) $((s%60))
}

# ── Barra de progresso ────────────────────────────────────────────────────────
# Uso: _progress_bar ATUAL TOTAL LABEL
_progress_bar() {
    local cur=$1 total=$2 label="${3:-}"
    local pct=$(( cur * 100 / total ))
    local filled=$(( cur * 30 / total ))
    local bar=""
    for ((i=0; i<filled; i++));   do bar+="█"; done
    for ((i=filled; i<30; i++)); do bar+="░"; done
    printf "\r  ${CYAN}[%s]${NC} %3d%% (%d/%d) %s" "$bar" "$pct" "$cur" "$total" "$label"
}

# ── Spinner para processos sem progresso mensurável ──────────────────────────
_spinner_start() {
    local pid=$1 label="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local start_t=$SECONDS
    while kill -0 "$pid" 2>/dev/null; do
        local i=$(( SECONDS % ${#spin} ))
        local elapsed=$(_elapsed $(( SECONDS - start_t )))
        printf "\r  ${YELLOW}${spin:$i:1}${NC} %s  [%s]" "$label" "$elapsed"
        sleep 0.3
    done
    printf "\r%-70s\r" " "   # limpa a linha
}

# ── Funções de controle ───────────────────────────────────────────────────────
STEPS_DONE_FILE="${OUTDIR}/.steps_done"
mkdir -p "${OUTDIR}/qza" "${OUTDIR}/taxonomy" "${OUTDIR}/exports" "${OUTDIR}/reports"
touch "$STEPS_DONE_FILE"

ALL_STEPS=(
    "01_download_sra"
    "02_build_manifest"
    "03_qiime_import"
    "03b_demux_summary"
    "04_dada2"
    "05_taxonomy"
    "06_filter_table"
    "07_export"
)

ALL_STEPS_LABELS=(
    "Download SRA"
    "Gerar Manifest"
    "Import QIIME 2"
    "Visualização de Qualidade"
    "DADA2 Denoising"
    "Taxonomia Silva"
    "Filtrar Tabela"
    "Exportar TSV/FASTA"
)

STEP_NUM=0   # contador global de etapa atual

step_done()   { grep -q "^$1$" "$STEPS_DONE_FILE" 2>/dev/null; }
mark_done()   { echo "$1" >> "$STEPS_DONE_FILE"; }
reset_step()  { sed -i "/^$1$/d" "$STEPS_DONE_FILE"; }
reset_all()   { > "$STEPS_DONE_FILE"; }

run_step() {
    local name="$1"; shift
    local total=${#ACTIVE_STEPS[@]}
    STEP_NUM=$(( STEP_NUM + 1 ))

    # Encontra o label amigável
    local label="$name"
    for i in "${!ALL_STEPS[@]}"; do
        if [[ "${ALL_STEPS[$i]}" == "$name" ]]; then
            label="${ALL_STEPS_LABELS[$i]}"
            break
        fi
    done

    if step_done "$name"; then
        echo -e "  ${GREEN}[✓]${NC} Etapa ${STEP_NUM}/${total} — ${BOLD}${label}${NC} ${GREEN}(já concluída, pulando)${NC}"
        return 0
    fi

    echo ""
    hdr "┌─ Etapa ${STEP_NUM}/${total}: ${label}"
    echo -e "│  ID: ${name}"
    echo -e "│  Início: $(date '+%H:%M:%S')"
    echo    "│"

    local LOG="${OUTDIR}/reports/${name}.log"
    local start_t=$SECONDS

    # Roda em background e mostra spinner
    "$@" > "$LOG" 2>&1 &
    local bg_pid=$!
    _spinner_start "$bg_pid" "Etapa ${STEP_NUM}/${total} — ${label}"
    wait "$bg_pid"
    local rc=$?

    local elapsed=$(_elapsed $(( SECONDS - start_t )))

    if [ $rc -eq 0 ]; then
        mark_done "$name"
        echo -e "└─ ${GREEN}[✓] Concluído${NC} em ${elapsed} → log: ${LOG}"
    else
        echo -e "└─ ${RED}[✗] Falhou${NC} após ${elapsed}"
        echo -e "   Veja o log: ${LOG}"
        echo ""
        echo "   Últimas linhas do erro:"
        tail -10 "$LOG" | sed 's/^/   /'
        exit 1
    fi
}

# ── Aplicar opções de controle ────────────────────────────────────────────────
if $RESET_ALL; then
    reset_all
    info "Todas as etapas resetadas."
elif [ -n "$RESET_STEP" ]; then
    reset_step "$(resolve_step "$RESET_STEP")"
    info "Etapa resetada: $(resolve_step "$RESET_STEP")"
fi

# Definir quais etapas rodar
if [ -n "$ONLY_STEP" ]; then
    RESOLVED=$(resolve_step "$ONLY_STEP")
    ACTIVE_STEPS=("$RESOLVED")
    reset_step "$RESOLVED"   # força reexecução mesmo que já feita
    info "Rodando apenas: $RESOLVED"
elif [ -n "$FROM_STEP" ]; then
    RESOLVED=$(resolve_step "$FROM_STEP")
    ACTIVE_STEPS=()
    found=false
    for s in "${ALL_STEPS[@]}"; do
        if [ "$s" = "$RESOLVED" ]; then found=true; fi
        if $found; then
            ACTIVE_STEPS+=("$s")
            reset_step "$s"
        fi
    done
    info "Iniciando a partir de: $RESOLVED"
else
    ACTIVE_STEPS=("${ALL_STEPS[@]}")
fi

# Remover etapa a pular
if [ -n "$SKIP_STEP" ]; then
    SKIP_ID=$(resolve_step "$SKIP_STEP")
    ACTIVE_STEPS=("${ACTIVE_STEPS[@]/$SKIP_ID/}")
    info "Pulando: $SKIP_ID"
fi

# ── Ativar QIIME 2 ───────────────────────────────────────────────────────────
CONDA_BASE="${HOME}/miniconda3"
source "${CONDA_BASE}/etc/profile.d/conda.sh"

# =============================================================================
PIPELINE_START=$SECONDS
echo ""
hdr "╔══════════════════════════════════════════════════════════╗"
hdr "║          Pipeline 16S rRNA — ${PROJECT_NAME}"
hdr "╠══════════════════════════════════════════════════════════╣"
echo -e "║  Início:   $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "║  Threads:  ${THREADS}  |  Modo: ${SEQ_MODE}"
echo -e "║  Etapas:   ${#ACTIVE_STEPS[@]} de ${#ALL_STEPS[@]}"

# Mostra o plano de execução
echo    "║"
echo    "║  Plano de execução:"
local_idx=0
for s in "${ACTIVE_STEPS[@]}"; do
    local_idx=$(( local_idx + 1 ))
    lbl=""
    for i in "${!ALL_STEPS[@]}"; do
        [[ "${ALL_STEPS[$i]}" == "$s" ]] && lbl="${ALL_STEPS_LABELS[$i]}" && break
    done
    if step_done "$s"; then
        echo -e "║    ${local_idx}. ${GREEN}[✓]${NC} ${lbl}"
    else
        echo -e "║    ${local_idx}. [ ] ${lbl}"
    fi
done
hdr "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── PASSO 1: Download SRA ────────────────────────────────────────────────────
_step_should_run() { [[ " ${ACTIVE_STEPS[*]} " == *" $1 "* ]]; }

# ── Download SRA (roda direto, sem redirecionar para log) ────────────────────
_do_download_sra() {
    local STEP_ID="01_download_sra"
    local total=${#ACTIVE_STEPS[@]}
    STEP_NUM=$(( STEP_NUM + 1 ))

    if step_done "$STEP_ID"; then
        echo -e "  ${GREEN}[✓]${NC} Etapa ${STEP_NUM}/${total} — ${BOLD}Download SRA${NC} ${GREEN}(já concluída, pulando)${NC}"
        return 0
    fi

    local SRA_BIN="${HOME}/miniconda3/envs/sra-tools/bin"
    local start_t=$SECONDS

    echo ""
    hdr "┌─ Etapa ${STEP_NUM}/${total}: Download SRA"
    echo -e "│  Início: $(date '+%H:%M:%S')"

    # Lê os IDs (suporta arquivo sem newline no final e formato Windows)
    local ids=()
    while IFS= read -r SRR || [ -n "$SRR" ]; do
        SRR="${SRR%%$'\r'}"
        [ -z "$SRR" ] && continue
        [[ "$SRR" == "#"* ]] && continue
        ids+=("$SRR")
    done < "${SRA_IDS_FILE}"

    local total_ids=${#ids[@]}
    echo -e "│  Total de amostras: ${BOLD}${total_ids}${NC}"
    echo    "│"

    mkdir -p "${READS_DIR}"
    mkdir -p "${OUTDIR}/reports"

    local idx=0 dl_ok=0 dl_skip=0

    for SRR in "${ids[@]}"; do
        idx=$(( idx + 1 ))
        local LOG="${OUTDIR}/reports/${STEP_ID}_${SRR}.log"

        # Já existe? Pula
        if ls "${READS_DIR}/${SRR}"*.fastq.gz &>/dev/null 2>&1; then
            dl_skip=$(( dl_skip + 1 ))
            echo -e "│  ${GREEN}[✓]${NC} (${idx}/${total_ids}) ${SRR} — já existe, pulando"
            continue
        fi

        echo -e "│"
        echo -e "│  ${YELLOW}[${idx}/${total_ids}]${NC} ${BOLD}${SRR}${NC}"

        # ── prefetch com monitor de tamanho ──────────────────────────────────
        printf "│    ⬇  prefetch... "
        local sra_dir="${READS_DIR}/${SRR}"
        rm -rf "$sra_dir"

        "${SRA_BIN}/prefetch" "${SRR}" \
            --max-size 100g \
            --output-directory "${READS_DIR}" \
            > "$LOG" 2>&1 &
        local prefetch_pid=$!

        local dot_count=0
        while kill -0 "$prefetch_pid" 2>/dev/null; do
            local sz
            sz=$(du -sh "${sra_dir}" 2>/dev/null | cut -f1 || echo "0B")
            printf "\r│    ⬇  prefetch... %-8s baixados" "$sz"
            sleep 2
        done
        wait "$prefetch_pid"
        local rc=$?
        local final_sz
        final_sz=$(du -sh "${sra_dir}" 2>/dev/null | cut -f1 || echo "?")
        if [ $rc -ne 0 ]; then
            echo ""
            echo -e "│    ${RED}[✗] prefetch falhou${NC} — veja: $LOG"
            tail -5 "$LOG" | sed 's/^/│        /'
            exit 1
        fi
        printf "\r│    ${GREEN}✓${NC}  prefetch concluído — %-8s\n" "$final_sz"

        # ── fasterq-dump ─────────────────────────────────────────────────────
        printf "│    ⚙  fasterq-dump (convertendo para FASTQ)..."
        "${SRA_BIN}/fasterq-dump" "${sra_dir}" \
            --outdir "${READS_DIR}" \
            --threads "${THREADS}" \
            --split-files \
            >> "$LOG" 2>&1 &
        local fq_pid=$!
        while kill -0 "$fq_pid" 2>/dev/null; do
            printf "."
            sleep 3
        done
        wait "$fq_pid"; rc=$?
        if [ $rc -ne 0 ]; then
            echo ""
            echo -e "│    ${RED}[✗] fasterq-dump falhou${NC} — veja: $LOG"
            tail -5 "$LOG" | sed 's/^/│        /'
            exit 1
        fi
        echo -e "\r│    ${GREEN}✓${NC}  fasterq-dump concluído                        "

        # ── pigz ─────────────────────────────────────────────────────────────
        printf "│    🗜  comprimindo com pigz..."
        pigz -p "${THREADS}" "${READS_DIR}/${SRR}"*.fastq >> "$LOG" 2>&1 &
        local pigz_pid=$!
        while kill -0 "$pigz_pid" 2>/dev/null; do
            printf "."
            sleep 2
        done
        wait "$pigz_pid"
        echo -e "\r│    ${GREEN}✓${NC}  compressão concluída                           "

        rm -rf "${sra_dir}"
        dl_ok=$(( dl_ok + 1 ))

        local sz_gz
        sz_gz=$(ls -lh "${READS_DIR}/${SRR}"*.fastq.gz 2>/dev/null | awk '{print $5}' | tr '\n' ' ')
        echo -e "│    📁 Arquivos: ${sz_gz}"
    done

    echo    "│"
    echo -e "│  ${GREEN}Baixados: ${dl_ok}${NC} | Pulados: ${dl_skip} | Total: ${total_ids}"
    local elapsed=$(_elapsed $(( SECONDS - start_t )))
    echo -e "└─ ${GREEN}[✓] Download concluído${NC} em ${elapsed}"

    mark_done "$STEP_ID"
}

_step_should_run "01_download_sra" && _do_download_sra

# ── PASSO 2: Manifest ─────────────────────────────────────────────────────────
_build_manifest() {
    conda activate qiime2-amplicon-2026.4
    python3 "$(dirname "$0")/../scripts/build_manifest.py" \
        --reads-dir "${READS_DIR}" \
        --mode "${SEQ_MODE}" \
        --output "${MANIFEST}"
    echo "  Amostras no manifest: $(grep -c '^[^#]' "${MANIFEST}" || true)"
}
_step_should_run "02_build_manifest" && run_step "02_build_manifest" _build_manifest

# ── PASSO 3: Import QIIME 2 ──────────────────────────────────────────────────
_qiime_import() {
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
_step_should_run "03_qiime_import" && run_step "03_qiime_import" _qiime_import

# ── PASSO 3b: Visualização de qualidade (opcional, para definir TRUNC_F/R) ───
_demux_summary() {
    conda activate qiime2-amplicon-2026.4
    qiime demux summarize \
        --i-data "${OUTDIR}/qza/demux.qza" \
        --o-visualization "${OUTDIR}/qza/demux-summary.qzv"
    echo ""
    echo "  Abra em: https://view.qiime2.org"
    echo "  Arquivo:  ${OUTDIR}/qza/demux-summary.qzv"
    echo ""
    echo "  Analise o gráfico de qualidade e ajuste no conf:"
    echo "    TRUNC_F=XXX   # posição onde qualidade cai abaixo de Q30 (forward)"
    echo "    TRUNC_R=XXX   # posição onde qualidade cai abaixo de Q30 (reverse)"
}
_step_should_run "03b_demux_summary" && run_step "03b_demux_summary" _demux_summary

# ── PASSO 4: DADA2 ───────────────────────────────────────────────────────────
_dada2() {
    conda activate qiime2-amplicon-2026.4
    local CMD=(
        qiime dada2 denoise-paired
        --i-demultiplexed-seqs "${OUTDIR}/qza/demux.qza"
        --p-trunc-len-f "${TRUNC_F}"
        --p-trunc-len-r "${TRUNC_R}"
        --p-trim-left-f "${TRIM_F}"
        --p-trim-left-r "${TRIM_R}"
        --p-max-ee-f "${MAX_EE_F}"
        --p-max-ee-r "${MAX_EE_R}"
        --p-n-threads "${THREADS}"
        --o-table "${OUTDIR}/qza/table.qza"
        --o-representative-sequences "${OUTDIR}/qza/rep-seqs.qza"
        --o-denoising-stats "${OUTDIR}/qza/denoising-stats.qza"
        --verbose
    )
    "${CMD[@]}"

    qiime metadata tabulate \
        --m-input-file "${OUTDIR}/qza/denoising-stats.qza" \
        --o-visualization "${OUTDIR}/qza/denoising-stats.qzv"
}
_step_should_run "04_dada2" && run_step "04_dada2" _dada2

# ── PASSO 5: Taxonomia ───────────────────────────────────────────────────────
_taxonomy() {
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
_step_should_run "05_taxonomy" && run_step "05_taxonomy" _taxonomy

# ── PASSO 6: Filtrar tabela ──────────────────────────────────────────────────
_filter_table() {
    conda activate qiime2-amplicon-2026.4
    qiime taxa filter-table \
        --i-table "${OUTDIR}/qza/table.qza" \
        --i-taxonomy "${OUTDIR}/taxonomy/taxonomy.qza" \
        --p-exclude mitochondria,chloroplast \
        --p-mode contains \
        --o-filtered-table "${OUTDIR}/qza/table-filtered.qza"

    qiime feature-table summarize \
        --i-table "${OUTDIR}/qza/table-filtered.qza" \
        --m-sample-metadata-file "${METADATA}" \
        --o-visualization "${OUTDIR}/qza/table-filtered.qzv"
}
_step_should_run "06_filter_table" && run_step "06_filter_table" _filter_table

# ── PASSO 7: Exportar ────────────────────────────────────────────────────────
_export() {
    conda activate qiime2-amplicon-2026.4
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
_step_should_run "07_export" && run_step "07_export" _export

# ── Fim ───────────────────────────────────────────────────────────────────────
TOTAL_ELAPSED=$(_elapsed $(( SECONDS - PIPELINE_START )))
echo ""
hdr "╔══════════════════════════════════════════════════════════╗"
echo -e "║  ${GREEN}✓ Pipeline concluído: ${PROJECT_NAME}${NC}"
echo    "║"
echo    "║  Resultados:  ${OUTDIR}/exports/"
echo -e "║  Término:     $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "║  Tempo total: ${TOTAL_ELAPSED}"
hdr "╚══════════════════════════════════════════════════════════╝"
echo ""
bash "$(dirname "$0")/../scripts/05_validate_checklist.sh" "${OUTDIR}"
