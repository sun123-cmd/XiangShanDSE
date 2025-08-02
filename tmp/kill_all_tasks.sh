#!/bin/bash

# XiangShan分布式测试完全停止脚本
# 停止所有本地和远程相关进程

echo "=========================================="
echo "XiangShan分布式测试停止脚本"
echo "时间: $(date)"
echo "=========================================="

# 服务器列表
SERVERS="open23 open24 open25 open26 open27 open15 open14 open13 open12 open11 open10 open09 open08 open07 open06"

echo "🔍 第一步: 停止本地主脚本进程..."

# 停止本地主脚本进程
echo "停止 xs_autorun_multiServer.py 进程..."
pkill -f "xs_autorun_multiServer.py" && echo "✅ xs_autorun_multiServer.py 已停止" || echo "❌ 未找到 xs_autorun_multiServer.py 进程"

echo "停止 cr-run.sh 进程..."
pkill -f "cr-run.sh" && echo "✅ cr-run.sh 已停止" || echo "❌ 未找到 cr-run.sh 进程"

echo "停止本地 emu 进程..."
pkill -9 -f "emu.*--diff" && echo "✅ 本地 emu 进程已停止" || echo "❌ 未找到本地 emu 进程"

echo ""
echo "🌐 第二步: 停止远程服务器上的进程..."

# 定义重试函数
retry_ssh() {
    local server=$1
    local command=$2
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no sunwenhao@$server "$command" 2>/dev/null; then
            return 0
        fi
        echo "   重试 $server (第$attempt次)..."
        ((attempt++))
        sleep 1
    done
    return 1
}

# 停止远程服务器上的进程
for server in $SERVERS; do
    echo "处理服务器: $server"
    
    # 检查并停止XiangShan emu进程
    if retry_ssh $server 'pgrep -u sunwenhao -f "emu.*--diff" > /dev/null'; then
        echo "  发现进程，正在停止..."
        if retry_ssh $server 'pkill -9 -u sunwenhao -f "emu"'; then
            echo "  ✅ $server: 进程已停止"
        else
            echo "  ❌ $server: 停止失败"
        fi
    else
        echo "  ✅ $server: 无相关进程"
    fi
done

echo ""
echo "🔍 第三步: 验证清理结果..."

# 验证本地进程
echo "本地进程检查:"
local_xs=$(pgrep -f "xs_autorun_multiServer.py" | wc -l)
local_cr=$(pgrep -f "cr-run.sh" | wc -l)
local_emu=$(pgrep -f "emu.*--diff" | wc -l)

echo "  xs_autorun_multiServer.py: $local_xs 个"
echo "  cr-run.sh: $local_cr 个"
echo "  emu进程: $local_emu 个"

# 验证远程进程
echo ""
echo "远程进程检查:"
total_remote=0
for server in $SERVERS; do
    if remote_count=$(retry_ssh $server 'pgrep -u sunwenhao -f "emu.*--diff" | wc -l' 2>/dev/null); then
        echo "  $server: $remote_count 个emu进程"
        total_remote=$((total_remote + remote_count))
    else
        echo "  $server: 连接失败"
    fi
done

echo ""
echo "=========================================="
echo "清理完成统计:"
echo "  本地总进程: $((local_xs + local_cr + local_emu)) 个"
echo "  远程总进程: $total_remote 个"

if [ $((local_xs + local_cr + local_emu + total_remote)) -eq 0 ]; then
    echo "🎉 所有进程已完全清理！"
    exit 0
else
    echo "⚠️  仍有进程未清理，可能需要手动处理"
    exit 1
fi 