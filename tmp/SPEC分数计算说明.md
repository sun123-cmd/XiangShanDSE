# SPEC2006测试方法与分数计算详解

## 1. 基本概念

SPEC（Standard Performance Evaluation Corporation）分数是衡量计算机性能的标准基准测试分数。SPEC2006包含两个主要测试套件：
- **SPECint2006**: 整数运算性能测试（12个基准程序）
- **SPECfp2006**: 浮点运算性能测试（17个基准程序）

## 2. 测试环境与工具

### 2.1 测试环境
- **处理器**: XiangShan RISC-V处理器
- **模拟器**: XiangShan emu模拟器
- **参考模型**: NEMU解释器
- **内存模拟**: DRAMsim3
- **测试平台**: 开芯院小机房服务器

### 2.2 核心工具
- **xs_autorun_multiServer.py**: 自动化测试脚本
- **emu**: XiangShan处理器模拟器
- **checkpoint**: SimPoint技术生成的检查点文件

## 3. 测试方法与运行步骤

### 3.1 运行前准备

3.1.1 拉取代码并编译emu：
```bash
git clone https://github.com/OpenXiangShan/XiangShan.git
cd XiangShan/
export NOOP_HOME=$(pwd)
#复位到指定ID，以及改相关硬件
git reset --hard xxxxxx
make init
python3 ./scripts/xiangshan.py --build --dramsim3 /nfs/home/zhangyuxin/spec_test/0218_spec_test/DRAMsim3 --with-dramsim3 --threads 16 --config KunminghuV2Config
#xiangshan_DDR4_8Gb_x8_3200_1ch_xmp为单通道，xiangshan_DDR4_8Gb_x8_3200_2ch_xmp为双通道
./build/emu --dramsim3-ini /nfs/home/zhangyuxin/spec_test/0218_spec_test/DRAMsim3/configs/xiangshan_DDR4_8Gb_x8_3200_1ch_xmp.ini --no-diff -i /nfs/home/zhangyuxin/temp/am_temp/am_new_for_pldm/nexus-am/apps/mem_test/mem_test_bw/build/mem_test_bw-riscv64-xs.bin >latency.log 2> perf.log
```

3.1.2 设置环境变量

在XiangShan目录下创建`env.sh`:

```bash
export XS_PROJECT_ROOT=$(pwd)
export NEMU_HOME=$(pwd)/NEMU
export AM_HOME=$(pwd)/nexus-am
export NOOP_HOME=$(pwd)/XiangShan
export DRAMSIM3_HOME=$(pwd)/DRAMsim3

echo SET XS_PROJECT_ROOT: ${XS_PROJECT_ROOT}
echo SET NOOP_HOME \(XiangShan RTL Home\): ${NOOP_HOME}
echo SET NEMU_HOME: ${NEMU_HOME}
echo SET AM_HOME: ${AM_HOME}
echo SET DRAMSIM3_HOME: ${DRAMSIM3_HOME}
```

3.1.3 基本路径配置

```bash
cd XiangShan
source env.sh # 同时需要把env.sh配置到bashrc以及bash_profile，参考6.1
mkdir tmp
```


3.1.4 运行脚本设置

在`./XiangShan/tmp`下，创建`cr-run.sh`：
```bash
#!/bin/bash
########## env ##########
DIVLINE=$(perl -E "print '=' x 20")

# 设置鲁棒SSH环境
function setup_robust_ssh(){
    echo "设置鲁棒SSH环境..."
    mkdir -p ~/.ssh/sockets
    export SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
    export SSH_AGENT_PID="$SSH_AGENT_PID"
    export SSH_OPTS="-o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
    echo "SSH环境配置完成"
}

function set_env(){
    cd /nfs/home/sunwenhao/XiangShan
    source ./env.sh

    PERF_HOME=/nfs/home/sunwenhao/XiangShan/tmp/perf
    checkpoint=/nfs/home/share/jiaxiaoyu/simpoint_checkpoint_archive/spec06_rv64gcb_O3_20m_gcc12.2.0-intFpcOff-jeMalloc/
    cpt_path_1=$checkpoint/checkpoint-0-0-0
    cover1_path_1=$cpt_path_1/cluster-0-0.json
    run_dir=/nfs/home/sunwenhao/XiangShan/tmp
    spec_dir=$run_dir/result
}

setup_robust_ssh
set_env

########## param: YOU SHOULD CONFIRM ##########
## small server
# server_list="open06 open07 open08 open09 open10 open12 open13 open14 open15" #open23 open24 open25 open26 open27"
## big server
# server_list="node005 node006 node007 node008 node009 node027 node028" #node003 node004
# node036 
server_list="open23 open24 open25 open26 open27 open15 open14 open13 open12 open11 open10 open09 open08 open07" #node003 node004
cpt_path=$cpt_path_1
json_path=$cover1_path_1
threads=16
version="kunminghu"
score_path=$run_dir/score-llvm19.1.0_rv64gcb_base_434.zeusmp.log
# if [[ $1 ]]; then
#     spec_dir=$1
# else
#     spec_dir="SPEC06_EmuTasks_"$(date +%m%d_%H%M)
# fi

########## make ##########
# echo "checkpoint test: $spec_dir"
# echo "========== make start at $(date) =========="
# make clean
# make -C $NOOP_HOME emu -j200 SIM_ARGS="" EMU_THREADS=$threads WITH_DRAMSIM3=1 EMU_TRACE=1
# echo "========== make end at $(date) =========="

########## run ##########
echo "********** cal start at $(date) **********"
cd $PERF_HOME

# 运行RTL
# python3 xs_autorun_multiServer.py $cpt_path $json_path \--ref /nfs/home/sunwenhao/XiangShan/ready-to-run/riscv64-nemu-interpreter-so \
# --xs $NOOP_HOME --threads $threads --dir $spec_dir --resume -L "$server_list"

# 运行RTL (带鲁棒SSH)
SSH_OPTS="$SSH_OPTS" python3 xs_autorun_multiServer.py $cpt_path $json_path \
--ref /nfs/home/sunwenhao/XiangShan/ready-to-run/riscv64-nemu-interpreter-so \
--xs $NOOP_HOME --threads $threads --dir $spec_dir --resume -L "$server_list"

# 运行RTL (限制运行1000条指令)
# python3 xs_autorun_multiServer.py $cpt_path $json_path --ref /nfs/home/sunwenhao/XiangShan/ready-to-run/riscv64-nemu-interpreter-so \
# --xs $NOOP_HOME --threads $threads --dir $spec_dir --resume -L "$server_list" --max-instr 1000

# 计算运行结果
# python3 xs_autorun_multiServer.py $cpt_path $json_path --xs $NOOP_HOME --threads $threads --dir $spec_dir --report > "$score_path"
# 打印运行状态
# python3 xs_autorun_multiServer.py $cpt_path $json_path --xs $NOOP_HOME --threads $threads --dir $spec_dir --show
# 邮箱推送
# python3 /nfs/home/share/liyanqin/scripts/ShareAutoEmailAlert.py -r $? --content "$spec_dir"
echo "********** cal end at $(date) **********"
```



### 3.2 运行方法

#### 3.2.1 完整SPEC2006测试
```bash
nohup ./cr-run.sh > output.log 2>&1 &
```

#### 3.2.2 监控当前测试

```bash
./monitor_results.sh
```

#### 3.2.3 停止当前测试
```bash
# 停止所有测试进程
./kill_all_tasks.sh
```

## 4. 分数计算公式

### 4.1 单个基准程序分数
```
单个程序分数 = 参考时间 / 实际运行时间
```

其中：
- **参考时间（Reference Time）**: 在标准参考机器上运行该程序的时间
- **实际运行时间**: 在被测试机器上运行该程序的时间

### 4.2 综合分数计算
SPEC使用**几何平均数**来计算综合分数：

```
SPEC分数 = (分数1 × 分数2 × ... × 分数n)^(1/n)
```

几何平均数的特点：
- 对异常值不敏感
- 能更好地反映整体性能
- 符合SPEC官方标准

## 5. SPEC分数计算依据

### 5.1 基于IPC的SPEC分数估算

```
估算SPEC分数 = 参考机器time / 测试机器time
```

### 5.2 权重计算
SPEC2006 INT基准测试使用以下权重：
```bash
declare -A spec_weights=(
    ["perlbench"]=0.4    # 文本处理
    ["bzip2"]=0.4        # 数据压缩
    ["gcc"]=1.0          # 编译器（最高权重）
    ["mcf"]=0.3          # 组合优化
    ["gobmk"]=0.3        # 围棋AI
    ["hmmer"]=0.3        # 蛋白质序列分析
    ["sjeng"]=0.3        # 国际象棋AI
    ["libquantum"]=0.3   # 量子计算模拟
    ["h264ref"]=0.3      # 视频编码
    ["omnetpp"]=0.3      # 网络仿真
    ["astar"]=0.3        # 路径查找
    ["xalancbmk"]=0.3    # XML处理
)
```

### 5.3 加权平均IPC计算
```bash
# 计算加权平均IPC
total_weighted_ipc = Σ(IPC_i × weight_i)
total_weight = Σ(weight_i)
average_ipc = total_weighted_ipc / total_weight
```

# 6 常见问题

## 6.1 Error 127
* 问题来源：ssh到新机器后，原始设置的临时环境变量缺失
* 解决方案：
修改本地`bashrc`为：
```bash
export NOOP_HOME=/nfs/home/sunwenhao/XiangShan
export NEMU_HOME=/nfs/home/sunwenhao/XiangShan/NEMU
export AM_HOME=/nfs/home/sunwenhao/XiangShan/nexus-am
export DRAMSIM3_HOME=/nfs/home/sunwenhao/XiangShan/DRAMsim3
export PATH=$NOOP_HOME/build:$PATH
export LD_LIBRARY_PATH=$NOOP_HOME/build:$LD_LIBRARY_PATH
```
同时，修改`bash_profile`为：

```bash
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
```

这样在加载ssh连接时，可以同步设置本地的环境变量到其他ssh节点

## 6.2 Error 255

* 问题来源：有时ssh连接超时会断
* 解决方案：设置鲁棒ssh，参考`cr-run.sh`中的鲁棒ssh选项，同时修改`./perf/server.py`，ssh断后自动重连

## 6.3 No numactl

* 问题来源： node06服务器上没有配置numactl的环境

* 解决方案：`cr-run.sh`脚本中删掉node06服务器