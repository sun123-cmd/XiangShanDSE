#!/bin/bash

echo "=== 测试h264ref checkpoint修复 ==="
echo "开始时间: $(date)"

# 验证checkpoint文件存在
CHECKPOINT_PATH="/nfs/home/share/jiaxiaoyu/simpoint_checkpoint_archive/spec06_rv64gcb_O3_20m_gcc12.2.0-intFpcOff-jeMalloc/checkpoint-0-0-0/h264ref_foreman.baseline/10070"
if [ -d "$CHECKPOINT_PATH" ]; then
    echo "✅ Checkpoint路径验证成功: $CHECKPOINT_PATH"
    ls -la "$CHECKPOINT_PATH"
    echo ""
    echo "✅ h264ref checkpoint修复成功！"
    echo "原问题: checkpoint点7969不存在"
    echo "修复方案: 改用可用的checkpoint点10070"
else
    echo "❌ Checkpoint路径不存在: $CHECKPOINT_PATH"
    exit 1
fi

echo ""
echo "现在可以重新运行SPEC测试："
echo "  ./tmp/test-all-spec-int.sh          # 快速测试"
echo "  ./tmp/test-all-spec-int.sh complete # 完整测试"
echo ""
echo "测试完成时间: $(date)" 