#!/bin/bash

# Check for input file argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 input_file"
    exit 1
fi

input_file="$1"
output_dir="genelists"

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Read input file line by line
while IFS= read -r line; do
    # Extract the first column as the filename
    filename=$(echo "$line" | awk '{print $1}')
    
    # Skip the first two columns and transpose the rest into a new file inside "genelists"
    echo "$line" | awk '{for (i=3; i<=NF; i++) print $i}' > "$output_dir/${filename}.txt"

done < "$input_file"

echo "Files created successfully in the '$output_dir' directory."
