#!/bin/bash

# Output files
bin_out="all_bin_annots.out"
cont_out="all_binned_contannots.out"

# Initialize output files
> "$bin_out"
> "$cont_out"

# Function to process a group of files
process_group() {
    suffix="$1"
    output="$2"
    compressed="$3"
    header_written=false

    for file in *sumstats_HM3_sldxr.gz_*sumstats_HM3_sldxr.gz${suffix}; do
        [ -e "$file" ] || continue

        # Extract P1 and P2
        base="${file%$suffix}"
        p1="${base%%.sumstats_HM3_sldxr.gz_*}"
        rest="${base#*.sumstats_HM3_sldxr.gz_}"
        p2="${rest%.sumstats_HM3_sldxr.gz}"

        # Choose the correct read command
        if $compressed; then
            reader="zcat \"$file\""
        else
            reader="cat \"$file\""
        fi

        eval "$reader" | awk -v p1="$p1" -v p2="$p2" -v hdr="$header_written" '
            BEGIN { OFS="\t" }
            NR==1 {
                if (hdr == "false") {
                    print "P1", "P2", $0
                }
                next
            }
            { print p1, p2, $0 }
        ' >> "$output"

        header_written=true
    done
}

# Process each group
process_group "" "$bin_out" true           # gzipped binary annotation results files
process_group "_contannot" "$cont_out" false  # uncompressed binned-continuous annotation results files
