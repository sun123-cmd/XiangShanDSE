#!/bin/bash

echo "=== 真正的SPEC2006分数计算 ==="
echo "基于参考时间文件和实际运行时间计算SPEC分数"
echo ""

# 参考时间文件路径
REF_TIME_FILE="/nfs/home/share/liyanqin/env-scripts/perf/json/gcc12o3-incFpcOff-jeMalloc-time.json"
TEST_DIR="/nfs/home/sunwenhao/XiangShan/tmp/result-all-spec-int-large"

# 检查参考时间文件
if [ ! -f "$REF_TIME_FILE" ]; then
    echo "错误：参考时间文件不存在: $REF_TIME_FILE"
    exit 1
fi

echo "使用参考时间文件: $REF_TIME_FILE"
echo "正在提取大规模测试结果..."

# 测试结果映射
declare -A test_mapping=(
    ["perlbench_checkspam"]="perlbench"
    ["bzip2_chicken"]="bzip2"
    ["gcc_166"]="gcc"
    ["mcf"]="mcf"
    ["gobmk_13x13"]="gobmk"
    ["hmmer_nph3"]="hmmer"
    ["sjeng"]="sjeng"
    ["libquantum"]="libquantum"
    ["h264ref_foreman.baseline"]="h264ref"
    ["omnetpp"]="omnetpp"
    ["astar_biglakes"]="astar"
    ["xalancbmk"]="xalancbmk"
)

# 初始化结果数组
declare -A actual_results
declare -A actual_times
declare -A reference_times

for benchmark in "${!test_mapping[@]}"; do
    actual_results[${test_mapping[$benchmark]}]="0.0"
    actual_times[${test_mapping[$benchmark]}]="0.0"
    reference_times[${test_mapping[$benchmark]}]="0.0"
done

# 自动提取IPC结果和运行时间
for test_name in "${!test_mapping[@]}"; do
    benchmark=${test_mapping[$test_name]}
    
    # 查找匹配的目录
    found=false
    for dir in "$TEST_DIR"/*; do
        if [[ -d "$dir" && "$dir" == *"$test_name"* ]]; then
            output_file="$dir/simulator_out.txt"
            if [ -f "$output_file" ]; then
                # 提取IPC值
                ipc_line=$(grep "IPC = " "$output_file" | tail -1)
                if [[ $ipc_line =~ IPC[[:space:]]*=[[:space:]]*([0-9.]+) ]]; then
                    ipc=${BASH_REMATCH[1]}
                    actual_results[$benchmark]=$ipc
                    
                    # 提取运行时间（CPU周期数）
                    cycle_line=$(grep "cycleCnt = " "$output_file" | tail -1)
                    if [[ $cycle_line =~ cycleCnt[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
                        cycles=${BASH_REMATCH[1]}
                        # 存储周期数，用于相对性能计算
                        actual_times[$benchmark]=$cycles
                        echo "✓ $benchmark: IPC=$ipc, 周期数=${cycles} (从 $(basename $dir))"
                    else
                        echo "✓ $benchmark: IPC=$ipc, 周期数=未知 (从 $(basename $dir))"
                    fi
                    found=true
                    break
                fi
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo "✗ $benchmark: 未找到结果文件"
    fi
done
echo ""

echo "实际测试结果:"
echo "基准测试    | IPC      | 周期数"
echo "------------|----------|--------"
for benchmark in "${!actual_results[@]}"; do
    ipc=${actual_results[$benchmark]}
    cycles=${actual_times[$benchmark]}
    if (( $(echo "$ipc > 0" | bc -l) )); then
        printf "%-12s | %-8s | %s\n" "$benchmark" "$ipc" "$cycles"
    else
        printf "%-12s | %-8s | %s\n" "$benchmark" "未完成" "未知"
    fi
done
echo ""

echo "=== 提取参考时间 ==="

# 从参考时间文件中提取对应checkpoint的参考时间
for test_name in "${!test_mapping[@]}"; do
    benchmark=${test_mapping[$test_name]}
    
    # 从目录名中提取checkpoint信息
    for dir in "$TEST_DIR"/*; do
        if [[ -d "$dir" && "$dir" == *"$test_name"* ]]; then
            dirname=$(basename "$dir")
            # 提取checkpoint点，例如：perlbench_checkspam_31059_0.134132 -> 31059
            if [[ $dirname =~ _([0-9]+)_[0-9.]+$ ]]; then
                checkpoint=${BASH_REMATCH[1]}
                
                # 从JSON文件中提取参考时间
                ref_time=$(python3 -c "
import json
import sys
try:
    with open('$REF_TIME_FILE', 'r') as f:
        data = json.load(f)
    if '$test_name' in data and 'times' in data['$test_name'] and '$checkpoint' in data['$test_name']['times']:
        print(data['$test_name']['times']['$checkpoint'])
    else:
        print('0')
except:
    print('0')
")
                
                if [ "$ref_time" != "0" ]; then
                    # 存储参考周期数
                    reference_times[$benchmark]=$ref_time
                    echo "✓ $benchmark: 参考周期数=${ref_time} (checkpoint=$checkpoint)"
                else
                    echo "✗ $benchmark: 未找到参考时间 (checkpoint=$checkpoint)"
                fi
                break
            fi
        fi
    done
done
echo ""

echo "=== SPEC2006分数计算 ==="
echo "基准测试    | 实际周期数 | 参考周期数 | SPEC分数"
echo "------------|------------|------------|----------"

total_spec_score=1.0
completed_tests=0

for benchmark in "${!actual_results[@]}"; do
    actual_cycles=${actual_times[$benchmark]}
    ref_cycles=${reference_times[$benchmark]}
    
    if (( $(echo "$actual_cycles > 0" | bc -l) )) && (( $(echo "$ref_cycles > 0" | bc -l) )); then
        # 计算SPEC分数：参考周期数 / 实际周期数
        spec_score=$(echo "$ref_cycles / $actual_cycles" | bc -l)
        total_spec_score=$(echo "$total_spec_score * $spec_score" | bc -l)
        completed_tests=$((completed_tests + 1))
        
        printf "%-12s | %-10s | %-10s | %-8s\n" "$benchmark" "$actual_cycles" "$ref_cycles" "$spec_score"
    else
        printf "%-12s | %-10s | %-10s | %-8s\n" "$benchmark" "未完成" "未找到" "-"
    fi
done

echo "------------|-------------|-------------|----------"

# 计算几何平均SPEC分数
if [ $completed_tests -gt 0 ]; then
    # 使用几何平均数计算最终SPEC分数
    final_spec_score=$(echo "e(l($total_spec_score)/$completed_tests)" | bc -l)
    
    echo ""
    echo "=== 最终SPEC2006分数 ==="
    echo "完成测试数: $completed_tests/12"
    echo "几何平均SPEC分数: $final_spec_score"
    echo ""
    
    # 性能评价
    if (( $(echo "$final_spec_score > 10" | bc -l) )); then
        performance="⭐⭐⭐⭐⭐ 卓越"
    elif (( $(echo "$final_spec_score > 5" | bc -l) )); then
        performance="⭐⭐⭐⭐ 优秀"
    elif (( $(echo "$final_spec_score > 2" | bc -l) )); then
        performance="⭐⭐⭐ 良好"
    elif (( $(echo "$final_spec_score > 1" | bc -l) )); then
        performance="⭐⭐ 一般"
    else
        performance="⭐ 较低"
    fi
    
    echo "🎯 性能评价: $performance"
    echo ""
    echo "💡 说明："
    echo "  • SPEC分数 = 参考机器周期数 / 测试机器周期数"
    echo "  • 使用几何平均数计算最终分数"
    echo "  • 分数越高表示性能越好"
    echo "  • 注意：这是基于SimPoint采样的相对性能，不是完整SPEC分数"
    echo ""
    echo "🌟 您的XiangShan处理器SPEC2006分数: $final_spec_score"
    
else
    echo "错误：没有完成任何测试或缺少参考时间"
fi

 