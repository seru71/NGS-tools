#!/usr/bin/Rscript
# Rscript for coverage statistics and number of features in a region of a bam file
# Rscript coverage.R '/export/astrakanfs/mpesj/Agilent/1040PRN0046_GRCh37.gatk.bam' 7 36399490 55889334 8

VERSION <- '1.3-May2014'

FEATURES <- '/export/astrakanfs/stefanj/reference/ccdsGene.hg19.mar2014.sqlite'
#FEATURES <- '/home/pawels/Work/mgm-projects/test-data/ccdsGene.hg19.mar2014.sqlite'

.libPaths('/export/astrakanfs/stefanj/R/library')
#suppressMessages(require(multicore,quiet=TRUE))
suppressMessages(require(GenomicFeatures,quiet=TRUE))
suppressMessages(require(SynergizeR,quiet=TRUE))

# get the curr dir and source shared functions
args <- commandArgs(trailingOnly = FALSE)
script.basename <- dirname(sub('--file=', '', args[grep('--file=', args)]))
source(paste(script.basename, 'shared_functions.R',sep='/'))


args <- commandArgs(trailingOnly = TRUE)
bam <- args[1]
chr <- args[2]
start <- as.integer(args[3])
end <- as.integer(args[4])
minCoverage <- as.integer(args[5])

# ccds <- parseBedFile('ccds.bed')
# bam <- '/export/astrakanfs/stefanj/Agilent/1040PRN0046_GRCh37.gatk.bam'
# chr <- 7
# start<-36399490
# end<-55889334
# minCoverage<-8
createBamIndex(bam)
bamRegion <- getSpecificRegion(chr,start,end,bam)
seqlevels(bamRegion) <- sub("^(\\d+)","chr\\1",seqlevels(bamRegion))

# To update the ccds gene database uncomment the 3 lines below.
# txdb <- makeTranscriptDbFromUCSC(genome='hg19',tablename='ccdsGene')
# saveFeatures(txdb,'<PATH>/ccdsGene.hg19.<date>.sqlite')
# stop('finished')
txdb = loadDb(FEATURES)

#Calulate transcript overlaps with the full genomic range
region <- GRanges(chr,IRanges(start, end))
seqlevels(region) <- sub("^(\\d+)","chr\\1",seqlevels(region))

hg19.transcripts <- transcriptsByOverlaps(txdb,region)
size.transcripts <- sum(width(hg19.transcripts))
number.transcripts <- length(hg19.transcripts)

hg19.exons <- exonsByOverlaps(txdb,region)
number.exons <- length(hg19.exons)

#intersect the transcript range with the actual reads reported, to calculate coverage
chrNr=paste('chr',chr,sep='')
coverage.transcripts <- Views(coverage(bamRegion, width=end)[chrNr],as(hg19.transcripts,"RangesList")[chrNr])
coverage.exons <- Views(coverage(bamRegion, width=end)[chrNr],as(hg19.exons,"RangesList")[chrNr])

#The mean is the weighted mean
coverage.exon.means <- viewMeans(coverage.exons)[[1]]%*%width(coverage.exons)[[1]]/sum(width(coverage.exons)[[1]])

# add coverage information to the GRanges object as metadata
elementMetadata(hg19.transcripts)['mean_coverage'] <- as.vector(viewMeans(coverage.transcripts))
elementMetadata(hg19.exons)['mean_coverage'] <- as.vector(viewMeans(coverage.exons))

transcripts.less_than_minimum.covered <- length(which(elementMetadata(hg19.transcripts)$mean_coverage < minCoverage))
exons.low_cvrg <- hg19.exons[elementMetadata(hg19.exons)$mean_coverage < minCoverage]
exons.low_cvrg.number <- length(exons.low_cvrg)

transcripts.less_than_minimum_covered.percent = round(transcripts.less_than_minimum.covered/number.transcripts*100)
exons.low_cvrg.percent = round(exons.low_cvrg.number/number.exons*100)

#exon to transcripts mapping
exons_to_transcripts <- as.matrix(findOverlaps(exons.low_cvrg,hg19.transcripts))
exons_to_transcripts[,2] <- elementMetadata(hg19.transcripts[exons_to_transcripts[, 2]])[, "tx_name"]
#which(exons_to_transcripts[,1] == '181')
#translate to hgnc_symbols from ccds transcript id's
#synergizer crashes if there is only one id
ids <- sub("\\..*",'',as.vector(elementMetadata(hg19.transcripts)[, "tx_name"]))
if (length(ids) == 1){
	ids<-append("",ids)
}
transcripts_to_genes <- data.frame(transcript=elementMetadata(hg19.transcripts)[, "tx_name"], 
                                   hgnc=synergizer(authority="ensembl", species="Homo sapiens", 
                                   domain="ccds", range="hgnc_symbol", ids=ids)[,2])
number.genes<-length(unique(transcripts_to_genes$hgnc))

cat('Script version', VERSION,'\n')
cat('Database', FEATURES,'\n\n')
cat(bam,'\n')
cat(paste('Candidate Region: ',chr,':',start,'-',end,sep=''))
cat('\n\n')
cat('Total length of Exons in candidate region overlapping capture enrichment:\n')
cat(paste(size.transcripts,'bp, ',number.genes,' genes, ',number.transcripts,' transcripts, ',number.exons,' exons, mean coverage: ',formatC(coverage.exon.means,digits=2,format='f'),'X\n',sep=''))
cat('List of genes in region:\n')
cat(as.vector(unique(transcripts_to_genes$hgnc[transcripts_to_genes$hgnc != "NA"])))
cat('\n')
# cat('Number and % of transcripts covered at mean < 8X:\n')
# cat(paste('n=',transcripts.less_than_minimum.covered,', ',transcripts.less_than_minimum_covered.percent,'% of target.\n',sep=''))
cat(paste('Number and % of exons covered at mean < ',minCoverage,'X:\n',sep=''))
cat(paste('n=',exons.low_cvrg.number,', ',exons.low_cvrg.percent,'% of target.\n',sep=''))

if (exons.low_cvrg.number > 0) {
    cat('\nList of poor coverage exons in region:\n')
    cat(paste('chromosome','start','end', 'mean_coverage','hgnc_symbol','transcript_id\n',sep='\t'))

    results <- as.data.frame(exons.low_cvrg)
    for(i in 1:exons.low_cvrg.number) {
        #meanCoverage <- formatC(unlist(elementMetadata(exons.low_cvrg[i])[1,"mean_coverage"],use.names=F),digits=2)
        meanCoverage=exons.low_cvrg$mean_coverage[i]
        transcripts <- exons_to_transcripts[which(exons_to_transcripts[,1] == i),2]
        genes <- c()
        for (transcript in exons_to_transcripts[which(exons_to_transcripts[,1] == i),2]) {
            genes <- append(genes, as.vector(transcripts_to_genes$hgnc[transcripts_to_genes$transcript==transcript]))
        }
        genes <- unique(na.omit(genes[genes != "NA"]))
        # chromosome <- results[i,][1]
		    chromosome <- chr
        chromstart <- results[i,][2]
        chromend <- results[i,][3]

        cat(paste(chromosome,chromstart,chromend,meanCoverage,'', sep="\t"))
        cat(genes)
        cat('\t')
        cat(transcripts)
        cat('\n')
    }
}


