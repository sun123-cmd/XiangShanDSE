#!/bin/bash

echo "=== XiangShan L3 Cache配置脚本使用演示 ==="
echo

echo "1. 查看脚本文件："
ls -la run_coremark_with_l3_config.sh
echo

echo "2. 使用方法示例："
echo "   # 使用默认配置 (1MB L3 Cache, 2个编译线程)"
echo "   ./run_coremark_with_l3_config.sh"
echo
echo "   # 配置512KB L3 Cache"
echo "   ./run_coremark_with_l3_config.sh 512"
echo
echo "   # 配置2MB L3 Cache, 使用4个编译线程"
echo "   ./run_coremark_with_l3_config.sh 2048 4"
echo

echo "3. 当前Configs.scala中的L3配置："
grep -A 5 -B 2 "sets = " src/main/scala/top/Configs.scala | head -8
echo

echo "4. 准备测试所需的文件："
echo "   ready-to-run/coremark-2-iteration.bin: $([ -f ready-to-run/coremark-2-iteration.bin ] && echo '存在' || echo '不存在')"
echo "   ready-to-run/riscv64-nemu-interpreter-so: $([ -f ready-to-run/riscv64-nemu-interpreter-so ] && echo '存在' || echo '不存在')"
echo

echo "5. 开始测试 - 配置512KB L3 Cache并运行CoreMark测试"
echo "   提示：这将花费几分钟时间进行编译和测试"
echo "   命令：./run_coremark_with_l3_config.sh 512 2"
echo

read -p "是否立即开始测试? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "开始执行测试..."
    ./run_coremark_with_l3_config.sh 512 2
else
    echo "演示结束。您可以稍后手动运行测试命令。"
    echo
    echo "快速命令参考："
    echo "  测试512KB:  ./run_coremark_with_l3_config.sh 512"
    echo "  测试1MB:    ./run_coremark_with_l3_config.sh 1024"
    echo "  测试2MB:    ./run_coremark_with_l3_config.sh 2048"
fi 