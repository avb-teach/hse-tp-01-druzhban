#!/bin/bash

################################################
#Help                                          #
################################################

Help() {
    echo "Script is copying all files from input directory to output directory"
    echo "Files are copied without hierarchy"
    echo "Same names will be copied with chaged names"
    echo "example: file.txt and file.txt -> file.txt file_1.txt"
    echo
    echo "Syntax: working_script.sh [-s] [--max_depth N] input_dir output_dir"
    echo "Options:"
    echo "  -s                Silent mode (without showing logs)"
    echo "  --max_depth N     Limit search depth"
    echo "  -h                show help message"
    echo
}

#################################################
#Some functions and variables                   #
#################################################

# wether logs are needed or not
silent=0
# wether file serach depth is limited
max_depth=-1

# for stats
dir_number=0
f_number=0
total_size=0

copy_file_with_suffix() {
    local file_path="$1"
    local short_name=$(basename "$file_path")
    local very_short_name="${short_name%.*}"
    local extension="${short_name##*.}"

    local output_dir_path="$output_dir/$short_name"
    local i=2

    while [[ -e "$output_dir_path" ]]; do
        output_dir_path="$output_dir/${very_short_name}_$i.$extension"
        ((i++))
    done

    cp "$file_path" "$output_dir_path"
    ((silent == 0)) && echo "Copied: $file_path -> $output_dir_path"
}

scan_dir() {
    local current_dir="$1"
    local depth="$2"

    if [[ $max_depth -ge 0 && $depth -gt $max_depth ]]; then
        return
    fi

    for entry in "$current_dir"/*; do
        if [[ -d "$entry" ]]; then
            ((dir_number++))
            scan_dir "$entry" $((depth + 1))
        elif [[ -f "$entry" ]]; then
            ((f_number++))
            local size=$(stat -c%s "$entry")
            total_size=$((total_size + size))
            copy_file_with_suffix "$entry"
        fi
    done
}

#################################################
#Working with options                           #
#################################################

positional_args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h)
            Help
            exit 0
            ;;
        -s)
            silent=1
            shift
            ;;
        --max_depth)
            max_depth="$2"
            shift 2
            ;;
        *)
            positional_args+=("$1")
            shift
            ;;
    esac
done

if [[ ${#positional_args[@]} -lt 2 ]]; then
    echo "Error: 2 arguments needed — input_dir и output_dir"
    Help
    exit 1
fi

input_dir="${positional_args[0]}"
output_dir="${positional_args[1]}"

#########################################
# The Mian part                         #
#########################################

if [[ ! -d "$input_dir" ]]; then
    echo "Error: input directory does not exist: $input_dir"
    exit 1
fi

mkdir -p "$output_dir"
scan_dir "$input_dir" 0

((silent == 0)) && echo
((silent == 0)) && echo "All done: $dir_number directories, $f_number files, $((total_size / 1024)) Kb copied"
