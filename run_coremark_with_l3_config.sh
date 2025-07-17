#!/bin/bash

# L3 Cache配置和CoreMark测试脚本
# 作者: Wenhao Sun
# 用法: ./run_coremark_with_l3_config.sh [L3_CACHE_SIZE_KB] [EMU_THREADS]
#
# 参数说明:
# L3_CACHE_SIZE_KB: L3缓存大小，单位KB (默认: 1024)
# EMU_THREADS: 编译线程数 (默认: 2)

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 默认参数
L3_CACHE_SIZE_KB=${1:-1024}  # 默认1MB
EMU_THREADS=${2:-2}          # 默认2线程
CONFIG_FILE="src/main/scala/top/Configs.scala"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# 验证参数
if ! [[ "$L3_CACHE_SIZE_KB" =~ ^[0-9]+$ ]] || [ "$L3_CACHE_SIZE_KB" -lt 256 ]; then
    print_error "L3缓存大小必须是大于等于256的整数"
    exit 1
fi

if ! [[ "$EMU_THREADS" =~ ^[0-9]+$ ]] || [ "$EMU_THREADS" -lt 1 ]; then
    print_error "线程数必须是大于等于1的整数"
    exit 1
fi

# 计算sets值
# XiangShan L3 Cache: sets × ways × blockSize × banks = total_size
# 默认配置: ways=8, blockSize=64B, banks=1
# 所以: sets = L3_CACHE_SIZE_KB * 1024 / (8 * 64 * 1)
SETS=$((L3_CACHE_SIZE_KB * 2))

print_info "=== XiangShan L3 Cache配置和CoreMark测试脚本 ==="
print_info "L3 Cache大小: ${L3_CACHE_SIZE_KB} KB"
print_info "计算得到的sets值: ${SETS}"
print_info "编译线程数: ${EMU_THREADS}"
echo

# 检查文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 备份原始配置文件
print_info "备份原始配置文件..."
cp "$CONFIG_FILE" "$BACKUP_FILE"
print_success "配置文件已备份到: $BACKUP_FILE"

# 修改L3 Cache配置
print_info "修改L3 Cache配置..."
if grep -q "sets = [0-9]*," "$CONFIG_FILE"; then
    # 替换现有的sets值
    sed -i "s/sets = [0-9]*,/sets = $SETS,/" "$CONFIG_FILE"
    print_success "已将L3 Cache sets值更新为: $SETS"
else
    print_error "在配置文件中找不到sets配置行"
    exit 1
fi

# 显示修改后的配置
print_info "当前L3 Cache配置:"
grep -A 3 -B 3 "sets = $SETS" "$CONFIG_FILE" || true

# 清理之前的构建
print_info "清理之前的构建文件..."
make clean > /dev/null 2>&1 || true

# 重新编译
print_info "开始重新编译 (使用 $EMU_THREADS 个线程)..."
echo "编译命令: make emu CONFIG=MinimalConfig EMU_THREADS=$EMU_THREADS -j32"

start_time=$(date +%s)
if make emu CONFIG=MinimalConfig EMU_THREADS="$EMU_THREADS" -j32; then
    end_time=$(date +%s)
    compile_time=$((end_time - start_time))
    print_success "编译完成，耗时: ${compile_time} 秒"
else
    print_error "编译失败"
    print_info "正在恢复原始配置文件..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi

# 检查生成的可执行文件
if [ ! -f "./build/emu" ]; then
    print_error "编译成功但未找到可执行文件: ./build/emu"
    exit 1
fi

emu_size=$(du -h ./build/emu | cut -f1)
print_success "生成的emu文件大小: $emu_size"

# 检查测试文件是否存在
if [ ! -f "./ready-to-run/coremark-2-iteration.bin" ]; then
    print_error "CoreMark测试文件不存在: ./ready-to-run/coremark-2-iteration.bin"
    exit 1
fi

if [ ! -f "./ready-to-run/riscv64-nemu-interpreter-so" ]; then
    print_error "NEMU参考模型不存在: ./ready-to-run/riscv64-nemu-interpreter-so"
    exit 1
fi

# 运行CoreMark测试
print_info "开始运行CoreMark测试..."
echo "测试命令: ./build/emu -b 0 -e 0 -i ./ready-to-run/coremark-2-iteration.bin --diff ./ready-to-run/riscv64-nemu-interpreter-so"

test_start_time=$(date +%s)
if ./build/emu -b 0 -e 0 -i ./ready-to-run/coremark-2-iteration.bin --diff ./ready-to-run/riscv64-nemu-interpreter-so; then
    test_end_time=$(date +%s)
    test_time=$((test_end_time - test_start_time))
    print_success "CoreMark测试完成，耗时: ${test_time} 秒"
else
    print_error "CoreMark测试失败"
    exit 1
fi

# 总结
echo
print_success "=== 任务完成总结 ==="
print_info "L3 Cache配置: ${L3_CACHE_SIZE_KB} KB (sets=${SETS})"
print_info "编译时间: ${compile_time} 秒"
print_info "测试时间: ${test_time} 秒"
print_info "备份文件: $BACKUP_FILE"

# 询问是否保留配置修改
echo
read -p "是否保留L3 Cache配置修改? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "恢复原始配置文件..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    print_success "配置文件已恢复"
else
    print_success "L3 Cache配置修改已保留"
fi

print_success "脚本执行完成!" 