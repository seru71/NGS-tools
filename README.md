NGS-tools
=========

Miscellanous scripts for NGS data analysis and visualisation
### gene_coverage.R

Calculates the coverage across all exons in a bam file, for a given set of genes

*    Running the script

     The script accepts a a bam file as the first option and any number of gene names, space
     separated.

*    Outputs

     The script will write to standard out a gene coverage info for each gene, together with
     individual exon coverage analysis for each gene. Exon position is derived from the ccds
     database. Updating the database should be done in the apropriate section of the script.

*    Typical usage

     Calculate gene coverage for LPT1 in bam `xxx.bam`:

        Rscript ~/bin/gene_coverage.R 'xxx.bam' LPT1

### region_coverage.R

Calulates coverage statistics for a specific region in the genome, along with exon coverage
for that region.

*    Running the script

     The script accepts a a bam file as the first option, chromosome number, start position,
     end position, and minimum coverage wanted for the report.

*    Outputs

     The script will write to standard out exon coverage information for the specified region.

*    Typical usage

     Calculate exon statistics for `xxx.bam` in chr7, between pos 36399490 and 55889334,
     with a minimum coverage of 8x:


