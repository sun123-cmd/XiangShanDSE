#!/bin/bash

RESULT_DIR="tmp/result"
LOG_FILE="monitoring.log"
COMPLETED_FILE="completed_tests.txt"
TOTAL_TESTS=1169  # 总测试项数量

# 创建记录文件
touch "$COMPLETED_FILE"

echo "=========================================="
echo "XiangShan测试监控开始"
echo "监控目录: $RESULT_DIR"
echo "日志文件: $LOG_FILE"
echo "已完成测试记录: $COMPLETED_FILE"
echo "=========================================="

# 记录开始时间
echo "[$(date)] 监控开始" >> "$LOG_FILE"


check_completed_tests() {
    local new_completed=0
    
    # 查找所有simulator_out.txt文件
    find "$RESULT_DIR" -name "simulator_out.txt" 2>/dev/null | while read -r file; do
        if [ -s "$file" ]; then  # 文件不为空
            test_name=$(basename $(dirname "$file"))
            test_dir=$(dirname "$file")
            error_file="$test_dir/simulator_err.txt"
            
            # 检查错误文件（忽略[PERF ]开头的行）
            if [ -s "$error_file" ]; then
                # 过滤掉[PERF ]开头的行，检查是否还有真正的错误
                real_errors=$(grep -v "^\[PERF \]" "$error_file" 2>/dev/null | grep -v "^$" | wc -l)
                if [ $real_errors -gt 0 ]; then
                    echo ""
                    echo "❌ =============== 测试错误 =============== ❌"
                    echo "🚨 测试名称: $test_name"
                    echo "📄 错误信息:"
                    tail -n 5 "$error_file" | grep -v "^\[PERF \]" | sed 's/^/    /'
                    echo "📁 错误文件: $error_file"
                    echo "⏰ 检测时间: $(date)"
                    echo "=============================================="
                    echo ""
                fi
            fi
            
            # 检查是否已经记录过
            if ! grep -q "$test_name" "$COMPLETED_FILE" 2>/dev/null; then
                
                # 检查成功标志
                if tail -n 5 "$file" 2>/dev/null | grep -q -E "(EXCEEDING CYCLE/INSTR LIMIT|instrCnt.*cycleCnt.*IPC|Host time spent)" ; then
                    
                    # 获取性能数据
                    ipc_line=$(tail -n 5 "$file" | grep -E "instrCnt.*cycleCnt.*IPC" || echo "IPC信息未找到")
                    time_line=$(tail -n 5 "$file" | grep -E "Host time spent" || echo "执行时间未找到")
                    
                    # 记录完成的测试
                    echo "$test_name" >> "$COMPLETED_FILE"
                    
                    # 静默记录，不显示完成信息
                    # 写入日志
                    echo "[$(date)] 完成测试: $test_name" >> "$LOG_FILE"
                    echo "  性能数据: $ipc_line" >> "$LOG_FILE"
                    echo "  执行时间: $time_line" >> "$LOG_FILE"
                    echo "" >> "$LOG_FILE"
                    
                    new_completed=$((new_completed + 1))
                fi
            fi
        fi
    done
    return $new_completed
}

# 显示统计信息
show_statistics() {
    local started_tests=$(find "$RESULT_DIR" -name "simulator_out.txt" 2>/dev/null | wc -l)
    local completed_tests=$([ -f "$COMPLETED_FILE" ] && wc -l < "$COMPLETED_FILE" || echo 0)
    local error_tests=$(find "$RESULT_DIR" -name "simulator_err.txt" -size +0 2>/dev/null | while read -r file; do
        # 检查是否有真正的错误（排除[PERF ]开头的行）
        if grep -v "^\[PERF \]" "$file" 2>/dev/null | grep -v "^$" | grep -q .; then
            echo "1"
        fi
    done | wc -l)
    local running_tests=$(ps aux | grep -c "[e]mu.*--diff" || echo 0)
    
    echo "📈 统计信息 [$(date '+%H:%M:%S')]"
    echo "   总测试项: $TOTAL_TESTS"
    echo "   已启动: $started_tests"
    echo "   已完成: $completed_tests"
    echo "   有错误: $error_tests"
    echo "   正在运行: $running_tests"
    echo "   启动率: $([ $TOTAL_TESTS -gt 0 ] && echo "scale=1; $started_tests * 100 / $TOTAL_TESTS" | bc || echo "0")%"
    echo "   完成率: $([ $TOTAL_TESTS -gt 0 ] && echo "scale=1; $completed_tests * 100 / $TOTAL_TESTS" | bc || echo "0")%"
    
    # 显示所有出错的测试项（排除[PERF ]开头的行）
    if [ $error_tests -gt 0 ]; then
        echo "❌ 出错的测试项:"
        find "$RESULT_DIR" -name "simulator_err.txt" -size +0 2>/dev/null | while read -r error_file; do
            # 检查是否有真正的错误（排除[PERF ]开头的行）
            if grep -v "^\[PERF \]" "$error_file" 2>/dev/null | grep -v "^$" | grep -q .; then
                test_name=$(basename $(dirname "$error_file"))
                echo "   • $test_name"
            fi
        done
    fi
    
    echo "----------------------------------------"
}

# 主监控循环
monitor_count=0
while true; do
    check_completed_tests
    
    # 每10次检查显示一次统计信息
    if [ $((monitor_count % 10)) -eq 0 ]; then
        show_statistics
        
        # 检查是否所有测试都完成了
        started_tests=$(find "$RESULT_DIR" -name "simulator_out.txt" 2>/dev/null | wc -l)
        completed_tests=$([ -f "$COMPLETED_FILE" ] && wc -l < "$COMPLETED_FILE" || echo 0)
        running_tests=$(ps aux | grep -c "[e]mu.*--diff" || echo 0)
        
        if [ "$completed_tests" -eq "$TOTAL_TESTS" ] && [ "$running_tests" -eq 0 ]; then
            echo ""
            echo "🎉 =============== 所有测试完成 =============== 🎉"
            echo "✅ 总测试数: $TOTAL_TESTS"
            echo "✅ 已完成: $completed_tests"
            echo "✅ 成功率: 100%"
            echo "⏰ 完成时间: $(date)"
            echo "=============================================="
            echo ""
            break
        fi
    fi
    
    monitor_count=$((monitor_count + 1))
    
    # 等待30秒再次检查
    sleep 30
done 