#!/bin/bash

echo "=== 大规模测试参数验证 ==="
echo "测试更大的workload参数是否合适"
echo "开始时间: $(date)"

# 环境变量
export NOOP_HOME=/nfs/home/sunwenhao/XiangShan
export NEMU_HOME=/nfs/home/sunwenhao/XiangShan/ready-to-run

# 测试参数 - 大规模测试
TEST_DIR=/nfs/home/sunwenhao/XiangShan/tmp/result-large-validation
mkdir -p $TEST_DIR

# 大规模参数
warmup_inst=50000     # 5万条预热指令
max_inst=500000       # 50万条测试指令
threads=1             # 单线程，专注测试

echo "测试目录: $TEST_DIR"
echo "使用线程数: $threads"
echo "预热指令数: $warmup_inst"
echo "最大指令数: $max_inst"
echo "预计测试时间: 约3-5分钟"

# 清理之前的进程
echo "清理之前的测试进程..."
pkill -f "xs_autorun_multiServer.py" 2>/dev/null
pkill -f "emu.*spec" 2>/dev/null
sleep 2

# 创建只包含一个基准测试的配置
TEMP_JSON=/tmp/large_scale_test.json
cat > $TEMP_JSON << 'EOF'
{
  "bzip2_chicken": {
    "points": {
      "2820": 0.251106
    }
  }
}
EOF

echo "使用大规模测试配置: $TEMP_JSON"

# 启动测试
echo "启动大规模测试验证..."
cd /nfs/home/sunwenhao/XiangShan/perf

start_time=$(date +%s)

python3 xs_autorun_multiServer.py \
  /nfs/home/share/jiaxiaoyu/simpoint_checkpoint_archive/spec06_rv64gcb_O3_20m_gcc12.2.0-intFpcOff-jeMalloc/checkpoint-0-0-0 \
  $TEMP_JSON \
  --ref /nfs/home/sunwenhao/XiangShan/ready-to-run/riscv64-nemu-interpreter-so \
  --xs $NOOP_HOME \
  --threads $threads \
  --dir $TEST_DIR \
  --warmup $warmup_inst \
  --max-instr $max_inst \
  --version 2006 \
  --isa rv64gcb

end_time=$(date +%s)
duration=$((end_time - start_time))

echo "测试完成时间: $(date)"
echo "总测试时间: ${duration}秒"

# 分析结果
echo "=== 大规模测试结果分析 ==="
output_file="$TEST_DIR/bzip2_chicken_2820_0.251106/simulator_out.txt"

if [ -f "$output_file" ]; then
    echo "找到输出文件，显示关键信息："
    echo "--- 文件大小 ---"
    ls -lh "$output_file"
    echo ""
    echo "--- 最后20行 ---"
    tail -20 "$output_file"
    echo ""
    echo "--- IPC信息 ---"
    grep "IPC = " "$output_file" | tail -5
    echo ""
    echo "--- 指令计数 ---"
    grep "instrCnt" "$output_file" | tail -3
    echo ""
    echo "--- 周期计数 ---"
    grep "cycleCnt" "$output_file" | tail -3
    echo ""
    
    # 计算IPC
    ipc_line=$(grep "IPC = " "$output_file" | tail -1)
    if [[ $ipc_line =~ IPC[[:space:]]*=[[:space:]]*([0-9.]+) ]]; then
        ipc=${BASH_REMATCH[1]}
        echo "🎯 最终IPC: $ipc"
        echo "⏱️  测试时间: ${duration}秒"
        echo "📊 指令数: 500,000"
        echo "✅ 大规模测试成功完成！"
    fi
else
    echo "❌ 未找到输出文件"
    ls -la $TEST_DIR/
fi 