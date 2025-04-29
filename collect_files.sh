
#!/bin/bash

################################################
#Help                                          #
################################################

Help() {
    echo "Script is copying all files from input directory to output directory"
    echo "Files are copied without hierarchy unless max_depth is set"
    echo "Same names will be copied with changed names"
    echo "example: file.txt and file.txt -> file1.txt file2.txt"
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

silent=0
max_depth=-1

dir_number=0
f_number=0
total_size=0

declare -A file_counters

copy_file_with_suffix() {
    local file_path="$1"
    local relative_path="$2"
    local target_dir=$(dirname "$output_dir/$relative_path")
    mkdir -p "$target_dir"

    local short_name=$(basename "$file_path")
    local base_name="${short_name%.*}"
    local extension="${short_name##*.}"

    if [[ "$base_name" == "$short_name" ]]; then
        extension=""
    else
        extension=".$extension"
    fi

    local key="$relative_path"
    local count=${file_counters["$key"]}
    if [[ -z "$count" ]]; then
        count=1
    else
        count=$((count + 1))
    fi
    file_counters["$key"]=$count

    local output_path="$target_dir/${base_name}${count}${extension}"
    cp "$file_path" "$output_path"
    ((silent == 0)) && echo "Copied: $file_path -> $output_path"
}

scan_dir() {
    local current_dir="$1"
    local depth="$2"
    local rel_path="$3"

    for entry in "$current_dir"/*; do
        if [[ -d "$entry" ]]; then
            ((dir_number++))
            local subdir_name=$(basename "$entry")
            scan_dir "$entry" $((depth + 1)) "$rel_path/$subdir_name"
        elif [[ -f "$entry" ]]; then
            ((f_number++))
            local size=$(stat -c%s "$entry")
            total_size=$((total_size + size))

            local short_name=$(basename "$entry")
            if [[ $max_depth -ge 0 && $depth -gt $max_depth ]]; then
                copy_file_with_suffix "$entry" "$short_name"
            elif [[ $max_depth -ge 0 ]]; then
                copy_file_with_suffix "$entry" "$rel_path/$short_name"
            else
                copy_file_with_suffix "$entry" "$short_name"
            fi
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
# The Main part                         #
#########################################

if [[ ! -d "$input_dir" ]]; then
    echo "Error: input directory does not exist: $input_dir"
    exit 1
fi

if [[ ! -d "$output_dir" ]]; then
    echo "Error: output directory does not exist: $output_dir"
    exit 1
fi

mkdir -p "$output_dir"
scan_dir "$input_dir" 0 ""

#########################################
# Renaming unique files back            #
#########################################
for relative_path in "${!file_counters[@]}"; do
    if [[ ${file_counters["$relative_path"]} -eq 1 ]]; then
        base_name="${relative_path##*/}"
        dir_path="${relative_path%/*}"
        if [[ "$dir_path" == "$relative_path" ]]; then
            dir_path=""
        fi
        base="${base_name%.*}"
        ext="${base_name##*.}"

        if [[ "$base" == "$base_name" ]]; then
            ext=""
        else
            ext=".$ext"
        fi

        file_with_1="$output_dir/$dir_path/${base}1$ext"
        final_name="$output_dir/$dir_path/${base}$ext"

        if [[ -e "$file_with_1" && ! -e "$final_name" ]]; then
            mv "$file_with_1" "$final_name"
            ((silent == 0)) && echo "Renamed: $file_with_1 -> $final_name"
        fi
    fi
done

((silent == 0)) && echo
((silent == 0)) && echo "All done: $dir_number directories, $f_number files, $((total_size / 1024)) Kb copied"