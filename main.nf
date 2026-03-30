#!/usr/bin/env nextflow
// =============================================================================
// Pipeline: Microbioma do Solo 16S rRNA (DADA2 + QIIME 2)
// Referência: nf-core/ampliseq
// =============================================================================
nextflow.enable.dsl = 2

// ── Parâmetros padrão ─────────────────────────────────────────────────────────
params.sra_ids        = null          // arquivo .txt com um SRA ID por linha
params.manifest       = null          // alternativa: manifest CSV já pronto
params.metadata        = "data/manifests/metadata.tsv"
params.outdir          = "results"
params.threads         = 16
params.paired_end      = true

// Parâmetros DADA2 (baseados no Q30 das amostras)
params.trunc_f         = 280          // Forward: truncar em 280 bp
params.trunc_r         = 235          // Reverse: truncar em 235 bp
params.trim_left_f     = 0
params.trim_left_r     = 0
params.max_ee_f        = 2
params.max_ee_r        = 2

// Classifier Silva (atualizado via script de download)
params.classifier      = "refs/silva-138-99-515-806-nb-classifier.qza"

// Ambiente conda QIIME 2
params.qiime_conda_env = "/home/edson/miniconda3/envs/qiime2-amplicon-2026.4"

// =============================================================================
// PROCESSO 1: Download SRA → FASTQ
// =============================================================================
process DOWNLOAD_SRA {
    tag "$sra_id"
    conda params.qiime_conda_env
    publishDir "${params.outdir}/raw", mode: 'copy'

    input:
    val sra_id

    output:
    tuple val(sra_id), path("${sra_id}*.fastq.gz"), emit: reads

    script:
    """
    prefetch ${sra_id} --output-directory .
    fasterq-dump ${sra_id} \
        --outdir . \
        --threads ${params.threads} \
        --split-files
    pigz -p ${params.threads} ${sra_id}*.fastq
    """
}

// =============================================================================
// PROCESSO 2: Gerar Manifest QIIME 2
// =============================================================================
process BUILD_MANIFEST {
    publishDir "${params.outdir}/manifests", mode: 'copy'

    input:
    path reads_dir

    output:
    path "manifest.tsv", emit: manifest

    script:
    def mode = params.paired_end ? "paired" : "single"
    """
    python3 ${projectDir}/scripts/build_manifest.py \
        --reads-dir ${reads_dir} \
        --mode ${mode} \
        --output manifest.tsv
    """
}

// =============================================================================
// PROCESSO 3: Importar para QIIME 2 (.qza)
// =============================================================================
process QIIME_IMPORT {
    conda params.qiime_conda_env
    publishDir "${params.outdir}/qza", mode: 'copy'

    input:
    path manifest

    output:
    path "demux.qza",     emit: demux
    path "demux-summary.qzv", emit: demux_viz

    script:
    def seq_type = params.paired_end \
        ? "SampleData[PairedEndSequencesWithQuality]" \
        : "SampleData[SequencesWithQuality]"
    def input_format = params.paired_end \
        ? "PairedEndFastqManifestPhred33V2" \
        : "SingleEndFastqManifestPhred33V2"

    """
    qiime tools import \
        --type '${seq_type}' \
        --input-path ${manifest} \
        --input-format ${input_format} \
        --output-path demux.qza

    qiime demux summarize \
        --i-data demux.qza \
        --o-visualization demux-summary.qzv \
        --p-n 100000
    """
}

// =============================================================================
// PROCESSO 4: DADA2 - Denoise (denoising + merge + chimera removal)
// =============================================================================
process DADA2_DENOISE {
    conda params.qiime_conda_env
    publishDir "${params.outdir}/qza", mode: 'copy'

    input:
    path demux

    output:
    path "table.qza",          emit: table
    path "rep-seqs.qza",       emit: rep_seqs
    path "denoising-stats.qza",emit: stats
    path "denoising-stats.qzv",emit: stats_viz

    script:
    def denoise_cmd = params.paired_end ? "denoise-paired" : "denoise-single"
    def rev_args    = params.paired_end ? """\\
        --p-trunc-len-r ${params.trunc_r} \\
        --p-trim-left-r ${params.trim_left_r} \\
        --p-max-ee-r ${params.max_ee_r}""" : ""

    """
    qiime dada2 ${denoise_cmd} \
        --i-demultiplexed-seqs ${demux} \
        --p-trunc-len-f ${params.trunc_f} \
        --p-trim-left-f ${params.trim_left_f} \
        --p-max-ee-f ${params.max_ee_f} \
        ${rev_args} \
        --p-n-threads ${params.threads} \
        --o-table table.qza \
        --o-representative-sequences rep-seqs.qza \
        --o-denoising-stats denoising-stats.qza \
        --verbose

    qiime metadata tabulate \
        --m-input-file denoising-stats.qza \
        --o-visualization denoising-stats.qzv
    """
}

// =============================================================================
// PROCESSO 5: Classificação Taxonômica (Silva)
// =============================================================================
process TAXONOMY {
    conda params.qiime_conda_env
    publishDir "${params.outdir}/taxonomy", mode: 'copy'

    input:
    path rep_seqs
    path classifier

    output:
    path "taxonomy.qza",        emit: taxonomy
    path "taxonomy.qzv",        emit: taxonomy_viz
    path "taxonomy-filtered.qza", emit: taxonomy_filtered

    script:
    """
    # Classificação
    qiime feature-classifier classify-sklearn \
        --i-classifier ${classifier} \
        --i-reads ${rep_seqs} \
        --p-n-jobs ${params.threads} \
        --o-classification taxonomy.qza

    # Visualização
    qiime metadata tabulate \
        --m-input-file taxonomy.qza \
        --o-visualization taxonomy.qzv

    # Remover mitocôndrias e cloroplastos
    qiime taxa filter-seqs \
        --i-sequences ${rep_seqs} \
        --i-taxonomy taxonomy.qza \
        --p-exclude mitochondria,chloroplast \
        --p-mode contains \
        --o-filtered-sequences taxonomy-filtered.qza
    """
}

// =============================================================================
// PROCESSO 6: Filtrar tabela (remover contaminantes)
// =============================================================================
process FILTER_TABLE {
    conda params.qiime_conda_env
    publishDir "${params.outdir}/qza", mode: 'copy'

    input:
    path table
    path taxonomy

    output:
    path "table-filtered.qza",     emit: table_filtered
    path "table-filtered.qzv",     emit: table_viz

    script:
    """
    qiime taxa filter-table \
        --i-table ${table} \
        --i-taxonomy ${taxonomy} \
        --p-exclude mitochondria,chloroplast \
        --p-mode contains \
        --o-filtered-table table-filtered.qza

    qiime feature-table summarize \
        --i-table table-filtered.qza \
        --m-sample-metadata-file ${params.metadata} \
        --o-visualization table-filtered.qzv
    """
}

// =============================================================================
// PROCESSO 7: Exportar (CSV/TSV + FASTA)
// =============================================================================
process EXPORT {
    conda params.qiime_conda_env
    publishDir "${params.outdir}/exports", mode: 'copy'

    input:
    path table_filtered
    path rep_seqs
    path taxonomy

    output:
    path "feature-table/",  emit: biom_dir
    path "sequences.fasta", emit: fasta
    path "taxonomy.tsv",    emit: taxonomy_tsv
    path "feature-table.tsv", emit: table_tsv

    script:
    """
    # Exportar tabela OTU/ASV (BIOM → TSV)
    qiime tools export \
        --input-path ${table_filtered} \
        --output-path feature-table

    biom convert \
        -i feature-table/feature-table.biom \
        -o feature-table.tsv \
        --to-tsv

    # Exportar sequências representativas (FASTA)
    qiime tools export \
        --input-path ${rep_seqs} \
        --output-path .
    mv dna-sequences.fasta sequences.fasta

    # Exportar taxonomia (TSV)
    qiime tools export \
        --input-path ${taxonomy} \
        --output-path .
    mv taxonomy.tsv taxonomy.tsv
    """
}

// =============================================================================
// WORKFLOW PRINCIPAL
// =============================================================================
workflow {

    // ── Modo 1: Download SRA ─────────────────────────────────────────────────
    if (params.sra_ids) {
        sra_ch = Channel
            .fromPath(params.sra_ids)
            .splitText()
            .map { it.trim() }
            .filter { it }

        reads_ch = DOWNLOAD_SRA(sra_ch)
        BUILD_MANIFEST(reads_ch.reads.collect())
        manifest_ch = BUILD_MANIFEST.out.manifest

    // ── Modo 2: Manifest já pronto ───────────────────────────────────────────
    } else if (params.manifest) {
        manifest_ch = Channel.fromPath(params.manifest)

    } else {
        error "Informe --sra_ids <arquivo.txt> ou --manifest <manifest.tsv>"
    }

    // ── Pipeline QIIME 2 ─────────────────────────────────────────────────────
    QIIME_IMPORT(manifest_ch)
    DADA2_DENOISE(QIIME_IMPORT.out.demux)

    classifier_ch = Channel.fromPath(params.classifier)
    TAXONOMY(DADA2_DENOISE.out.rep_seqs, classifier_ch)

    FILTER_TABLE(
        DADA2_DENOISE.out.table,
        TAXONOMY.out.taxonomy
    )

    EXPORT(
        FILTER_TABLE.out.table_filtered,
        TAXONOMY.out.taxonomy_filtered,
        TAXONOMY.out.taxonomy
    )
}
