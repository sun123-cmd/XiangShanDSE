#!/bin/bash

echo "=== 停止当前SPEC测试脚本 ==="
echo "停止时间: $(date)"

# 查找并停止Python测试进程
echo "1. 查找Python测试进程..."
PYTHON_PIDS=$(pgrep -f "xs_autorun_multiServer.py")
if [ -n "$PYTHON_PIDS" ]; then
    echo "发现Python进程: $PYTHON_PIDS"
    echo "正在停止Python进程..."
    pkill -f "xs_autorun_multiServer.py"
    sleep 3
    
    # 检查是否还有进程在运行
    REMAINING=$(pgrep -f "xs_autorun_multiServer.py")
    if [ -n "$REMAINING" ]; then
        echo "强制终止剩余进程: $REMAINING"
        pkill -9 -f "xs_autorun_multiServer.py"
    fi
else
    echo "未发现Python测试进程"
fi

# 查找并停止emu进程
echo "2. 查找emu进程..."
EMU_PIDS=$(pgrep -f "emu.*spec")
if [ -n "$EMU_PIDS" ]; then
    echo "发现emu进程: $EMU_PIDS"
    echo "正在停止emu进程..."
    pkill -f "emu.*spec"
    sleep 3
    
    # 检查是否还有进程在运行
    REMAINING=$(pgrep -f "emu.*spec")
    if [ -n "$REMAINING" ]; then
        echo "强制终止剩余emu进程: $REMAINING"
        pkill -9 -f "emu.*spec"
    fi
else
    echo "未发现emu进程"
fi

# 查找并停止SSH连接
echo "3. 查找SSH连接..."
SSH_PIDS=$(pgrep -f "ssh.*emu")
if [ -n "$SSH_PIDS" ]; then
    echo "发现SSH连接: $SSH_PIDS"
    echo "正在停止SSH连接..."
    pkill -f "ssh.*emu"
    sleep 2
else
    echo "未发现SSH连接"
fi

# 显示当前状态
echo "4. 当前进程状态:"
echo "Python测试进程:"
pgrep -f "xs_autorun_multiServer.py" || echo "无"
echo "emu进程:"
pgrep -f "emu.*spec" || echo "无"
echo "SSH连接:"
pgrep -f "ssh.*emu" || echo "无"

# 显示系统资源使用情况
echo "5. 系统资源使用情况:"
echo "CPU使用率:"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
echo "内存使用率:"
free | grep Mem | awk '{printf "%.1f%%\n", $3/$2 * 100.0}'
echo "系统负载:"
uptime | awk '{print $(NF-2), $(NF-1), $NF}'

# 显示测试目录状态
echo "6. 测试目录状态:"
TEST_DIRS=("/nfs/home/sunwenhao/XiangShan/tmp/result-local-spec" "/nfs/home/sunwenhao/XiangShan/tmp/result-full-spec")

for dir in "${TEST_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "目录: $dir"
        completed=$(find $dir -name "simulator_out.txt" 2>/dev/null | wc -l)
        failed=$(find $dir -name "simulator_err.txt" -size +0 2>/dev/null | wc -l)
        echo "  已完成任务: $completed"
        echo "  失败任务: $failed"
    fi
done

echo "=== 停止脚本完成 ==="
echo "完成时间: $(date)" 