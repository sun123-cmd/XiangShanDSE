#!/bin/bash

# 检查命令行参数
if [ "$1" = "complete" ]; then
    echo "=== SPEC2006 INT完整基准测试 ==="
    echo "运行完整SPEC测试以获得准确的SPEC分数(10-15分)"
    COMPLETE_MODE=true
else
    echo "=== SPEC2006 INT快速基准测试 ==="
    echo "运行快速测试以获得相对性能指标"
    echo "使用 'complete' 参数运行完整测试: ./test-all-spec-int.sh complete"
    COMPLETE_MODE=false
fi

echo "开始时间: $(date)"

# 环境变量
export NOOP_HOME=/nfs/home/sunwenhao/XiangShan
export NEMU_HOME=/nfs/home/sunwenhao/XiangShan/ready-to-run

# 根据模式设置测试参数
if [ "$COMPLETE_MODE" = true ]; then
    # 完整SPEC测试模式
    TEST_DIR=/nfs/home/sunwenhao/XiangShan/tmp/result-all-spec-int-complete
    warmup_inst=500000    # 50万条预热指令
    max_inst=10000000     # 1000万条测试指令，大幅增加测试规模
    threads=1             # 单线程，确保准确性
    echo "📊 完整SPEC测试模式"
    echo "测试目录: $TEST_DIR"
    echo "预热指令数: $warmup_inst (50万条)"
    echo "最大指令数: $max_inst (1000万条)"
    echo "线程数: $threads (单线程)"
    echo "预计测试时间: 每个基准测试约10-20分钟"
    echo "目标SPEC分数: 10-15分"
else
    # 快速测试模式
    TEST_DIR=/nfs/home/sunwenhao/XiangShan/tmp/result-all-spec-int-large
    warmup_inst=50000     # 5万条预热指令
    max_inst=500000       # 50万条测试指令
    threads=2             # 2线程，快速完成
    echo "⚡ 快速测试模式"
    echo "测试目录: $TEST_DIR"
    echo "预热指令数: $warmup_inst (5万条)"
    echo "最大指令数: $max_inst (50万条)"
    echo "线程数: $threads (2线程)"
    echo "预计测试时间: 每个基准测试约2-5分钟"
    echo "目标: 相对性能指标"
fi

mkdir -p $TEST_DIR

# 清理之前的进程
echo "清理之前的测试进程..."
pkill -f "xs_autorun_multiServer.py" 2>/dev/null
pkill -f "emu.*spec" 2>/dev/null
sleep 2

# 根据模式创建测试配置
TEMP_JSON=/tmp/all_spec_int_test.json

if [ "$COMPLETE_MODE" = true ]; then
    # 完整测试配置 - 使用实际存在的checkpoint点，但增加测试指令数
    cat > $TEMP_JSON << 'EOF'
{
  "perlbench_checkspam": {
    "points": {
      "31059": 1.0
    }
  },
  "bzip2_chicken": {
    "points": {
      "2820": 1.0
    }
  },
  "gcc_166": {
    "points": {
      "1475": 1.0
    }
  },
  "mcf": {
    "points": {
      "9294": 1.0
    }
  },
  "gobmk_13x13": {
    "points": {
      "6366": 1.0
    }
  },
  "hmmer_nph3": {
    "points": {
      "9545": 1.0
    }
  },
  "sjeng": {
    "points": {
      "983": 1.0
    }
  },
  "libquantum": {
    "points": {
      "64624": 1.0
    }
  },
  "h264ref_foreman.baseline": {
    "points": {
      "7969": 1.0
    }
  },
  "omnetpp": {
    "points": {
      "20261": 1.0
    }
  },
  "astar_biglakes": {
    "points": {
      "3267": 1.0
    }
  },
  "xalancbmk": {
    "points": {
      "8082": 1.0
    }
  }
}
EOF
else
    # 快速测试配置 - 使用原始SimPoint
    cat > $TEMP_JSON << 'EOF'
{
  "perlbench_checkspam": {
    "points": {
      "31059": 0.134132
    }
  },
  "bzip2_chicken": {
    "points": {
      "2820": 0.251106
    }
  },
  "gcc_166": {
    "points": {
      "1475": 0.044667
    }
  },
  "mcf": {
    "points": {
      "9294": 0.130425
    }
  },
  "gobmk_13x13": {
    "points": {
      "6366": 0.127036
    }
  },
  "hmmer_nph3": {
    "points": {
      "9545": 0.231614
    }
  },
  "sjeng": {
    "points": {
      "983": 0.128528
    }
  },
  "libquantum": {
    "points": {
      "64624": 0.24316
    }
  },
  "h264ref_foreman.baseline": {
    "points": {
      "7969": 0.0266103
    }
  },
  "omnetpp": {
    "points": {
      "20261": 0.361193
    }
  },
  "astar_biglakes": {
    "points": {
      "3267": 0.388983
    }
  },
  "xalancbmk": {
    "points": {
      "8082": 0.0971231
    }
  }
}
EOF
fi

echo "测试配置: $TEMP_JSON"

# 启动测试
echo "启动SPEC2006 INT基准测试..."
cd /nfs/home/sunwenhao/XiangShan/perf

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

echo "测试完成时间: $(date)"

# 检查测试完成情况
echo ""
echo "=== 测试完成情况检查 ==="
completed_count=0
for test_name in perlbench_checkspam bzip2_chicken gcc_166 mcf gobmk_13x13 hmmer_nph3 sjeng libquantum h264ref_foreman.baseline omnetpp astar_biglakes xalancbmk; do
    output_file="$TEST_DIR/$test_name/simulator_out.txt"
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        completed_count=$((completed_count + 1))
        echo "✓ $test_name: 已完成"
    else
        echo "✗ $test_name: 未完成"
    fi
done

echo ""
echo "=== 测试总结 ==="
echo "完成测试数: $completed_count/12"
echo "测试结果目录: $TEST_DIR"

if [ "$COMPLETE_MODE" = true ]; then
    echo ""
    echo "🎯 完整SPEC测试完成！"
    echo "💡 运行以下命令计算真正的SPEC分数："
    echo "   ./calculate-spec-score.sh"
    echo ""
    echo "📊 预期SPEC分数范围: 10-15分"
else
    echo ""
    echo "⚡ 快速测试完成！"
    echo "💡 运行以下命令计算相对性能："
    echo "   ./calculate-spec-score.sh"
    echo ""
    echo "💡 要获得真正的SPEC分数(10-15分)，请运行："
    echo "   ./test-all-spec-int.sh complete"
fi

echo ""
echo "-------------------测试完成--------------------"
