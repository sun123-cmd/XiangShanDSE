#!/bin/bash

# Multi-configuration CoreMark test script for XiangShan
# This script allows running CoreMark tests on different emu configurations

set -e

# Default values
COREMARK_PATH=${COREMARK_PATH:-""}
ITERATIONS=${ITERATIONS:-1}
OUTPUT_DIR=${OUTPUT_DIR:-"coremark_results"}
COMPARE_ONLY=false
HELP=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--path)
            COREMARK_PATH="$2"
            shift 2
            ;;
        -i|--iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --compare)
            COMPARE_ONLY=true
            shift
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Show help
if [ "$HELP" = true ]; then
    cat << EOF
Usage: $0 [OPTIONS] [EMU_CONFIGS...]

Multi-configuration CoreMark test script for XiangShan

OPTIONS:
    -p, --path PATH         Path to CoreMark binary (required unless --compare)
    -i, --iterations N      Number of iterations per config (default: 1)
    -o, --output DIR        Output directory for results (default: coremark_results)
    --compare               Compare existing results only
    -h, --help              Show this help message

EMU_CONFIGS:
    List of emu configurations to test (e.g., emu_default emu_l3_1mb emu_l3_2mb)
    If not specified, will auto-detect available emu configurations

EXAMPLES:
    # Run CoreMark on all available emu configurations
    $0 -p /path/to/coremark.riscv

    # Run CoreMark on specific configurations
    $0 -p /path/to/coremark.riscv emu_default emu_l3_1mb

    # Run with multiple iterations
    $0 -p /path/to/coremark.riscv -i 3

    # Compare existing results
    $0 --compare

ENVIRONMENT VARIABLES:
    COREMARK_PATH    Path to CoreMark binary
    ITERATIONS       Number of iterations per config
    OUTPUT_DIR       Output directory for results

EOF
    exit 0
fi

# Function to find available emu configurations
find_emu_configs() {
    local configs=()
    
    # Check for symlinks first
    for symlink in emu_*; do
        if [ -L "$symlink" ] && [ -x "$symlink" ]; then
            configs+=("$symlink")
        fi
    done
    
    # Check for build directories
    for build_dir in build_*; do
        if [ -d "$build_dir" ] && [ -x "$build_dir/emu" ]; then
            config_name="emu_${build_dir#build_}"
            configs+=("$config_name")
        fi
    done
    
    # Check default build directory
    if [ -x "build/emu" ]; then
        configs+=("build/emu")
    fi
    
    echo "${configs[@]}"
}

# Function to run CoreMark test
run_coremark() {
    local emu_path="$1"
    local config_name="$2"
    local iteration="$3"
    
    echo "Running CoreMark test on $config_name (iteration $iteration)..."
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Run CoreMark
    local output_file="$OUTPUT_DIR/${config_name}_iter${iteration}.log"
    local start_time=$(date +%s)
    
    echo "Starting CoreMark test at $(date)" | tee "$output_file"
    echo "Emu: $emu_path" | tee -a "$output_file"
    echo "CoreMark binary: $COREMARK_PATH" | tee -a "$output_file"
    echo "========================================" | tee -a "$output_file"
    
    # Run emu with CoreMark
    timeout 300 "$emu_path" -i "$COREMARK_PATH" 2>&1 | tee -a "$output_file"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "========================================" | tee -a "$output_file"
    echo "Test completed in ${duration}s at $(date)" | tee -a "$output_file"
    
    # Extract CoreMark score
    local score=$(grep -E "CoreMark 1.0 : [0-9.]+" "$output_file" | tail -1 | awk '{print $4}')
    if [ -n "$score" ]; then
        echo "CoreMark score: $score" | tee -a "$output_file"
        echo "$score" > "$OUTPUT_DIR/${config_name}_iter${iteration}.score"
    else
        echo "CoreMark score: Not found" | tee -a "$output_file"
        echo "N/A" > "$OUTPUT_DIR/${config_name}_iter${iteration}.score"
    fi
    
    echo ""
}

# Function to compare results
compare_results() {
    echo "Comparing CoreMark results..."
    echo "=============================="
    
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo "No results directory found: $OUTPUT_DIR"
        exit 1
    fi
    
    # Find all score files
    local score_files=($(find "$OUTPUT_DIR" -name "*.score" | sort))
    
    if [ ${#score_files[@]} -eq 0 ]; then
        echo "No score files found in $OUTPUT_DIR"
        exit 1
    fi
    
    echo "Configuration                    | Score     | Iteration"
    echo "--------------------------------|-----------|----------"
    
    for score_file in "${score_files[@]}"; do
        local config_name=$(basename "$score_file" .score | sed 's/_iter[0-9]*$//')
        local iteration=$(basename "$score_file" .score | sed 's/.*_iter//')
        local score=$(cat "$score_file")
        
        printf "%-32s | %-9s | %s\n" "$config_name" "$score" "$iteration"
    done
    
    echo ""
    echo "Detailed results are available in: $OUTPUT_DIR"
}

# Function to generate summary report
generate_summary() {
    local summary_file="$OUTPUT_DIR/summary.txt"
    
    echo "CoreMark Performance Summary" > "$summary_file"
    echo "=============================" >> "$summary_file"
    echo "Generated at: $(date)" >> "$summary_file"
    echo "" >> "$summary_file"
    
    # Group by configuration
    local configs=($(find "$OUTPUT_DIR" -name "*.score" | sed 's/.*\///' | sed 's/_iter[0-9]*\.score$//' | sort | uniq))
    
    for config in "${configs[@]}"; do
        echo "Configuration: $config" >> "$summary_file"
        echo "----------------------" >> "$summary_file"
        
        local scores=($(find "$OUTPUT_DIR" -name "${config}_iter*.score" | sort | xargs cat))
        local valid_scores=()
        
        for score in "${scores[@]}"; do
            if [ "$score" != "N/A" ]; then
                valid_scores+=("$score")
            fi
        done
        
        if [ ${#valid_scores[@]} -gt 0 ]; then
            # Calculate statistics
            local sum=0
            local count=0
            for score in "${valid_scores[@]}"; do
                sum=$(echo "$sum + $score" | bc -l)
                ((count++))
            done
            
            local avg=$(echo "scale=2; $sum / $count" | bc -l)
            local min=$(printf '%s\n' "${valid_scores[@]}" | sort -n | head -1)
            local max=$(printf '%s\n' "${valid_scores[@]}" | sort -n | tail -1)
            
            echo "  Valid runs: $count" >> "$summary_file"
            echo "  Average: $avg" >> "$summary_file"
            echo "  Min: $min" >> "$summary_file"
            echo "  Max: $max" >> "$summary_file"
        else
            echo "  No valid scores found" >> "$summary_file"
        fi
        
        echo "" >> "$summary_file"
    done
    
    echo "Summary report generated: $summary_file"
}

# Main execution
if [ "$COMPARE_ONLY" = true ]; then
    compare_results
    generate_summary
    exit 0
fi

# Validate CoreMark path
if [ -z "$COREMARK_PATH" ]; then
    echo "Error: CoreMark binary path must be specified with -p/--path"
    exit 1
fi

if [ ! -f "$COREMARK_PATH" ]; then
    echo "Error: CoreMark binary not found: $COREMARK_PATH"
    exit 1
fi

# Find emu configurations
if [ $# -eq 0 ]; then
    echo "Auto-detecting emu configurations..."
    EMU_CONFIGS=($(find_emu_configs))
else
    EMU_CONFIGS=("$@")
fi

if [ ${#EMU_CONFIGS[@]} -eq 0 ]; then
    echo "Error: No emu configurations found"
    echo "Please build emu first using: ./scripts/build_multi_config.sh"
    exit 1
fi

echo "Found ${#EMU_CONFIGS[@]} emu configuration(s):"
for config in "${EMU_CONFIGS[@]}"; do
    echo "  - $config"
done
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run tests
for config in "${EMU_CONFIGS[@]}"; do
    # Determine emu path
    if [ -L "$config" ]; then
        emu_path="$config"
        config_name="$config"
    elif [ -f "$config" ]; then
        emu_path="$config"
        config_name=$(basename "$config")
    else
        echo "Warning: Configuration not found: $config"
        continue
    fi
    
    # Run iterations
    for ((i=1; i<=ITERATIONS; i++)); do
        run_coremark "$emu_path" "$config_name" "$i"
    done
done

# Compare results
echo "All tests completed!"
echo ""
compare_results
generate_summary

echo ""
echo "Results saved in: $OUTPUT_DIR"
echo "Summary report: $OUTPUT_DIR/summary.txt" 