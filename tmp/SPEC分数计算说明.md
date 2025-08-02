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
- **测试平台**: Linux系统

### 2.2 核心工具
- **xs_autorun_multiServer.py**: 自动化测试脚本
- **emu**: XiangShan处理器模拟器
- **checkpoint**: SimPoint技术生成的检查点文件

## 3. 测试方法与运行步骤


### 3.1 运行方法

#### 3.1.1 完整SPEC2006测试
```bash
nohup ./cr-run.sh > output.log 2>&1 &
```

#### 3.1.2 监控当前测试

```bash
./monitor_results.sh
```

#### 3.1.3 停止当前测试
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
修改本地`   bashrc`为：
```
export NOOP_HOME=/nfs/home/sunwenhao/XiangShan
export NEMU_HOME=/nfs/home/sunwenhao/XiangShan/NEMU
export AM_HOME=/nfs/home/sunwenhao/XiangShan/nexus-am
export DRAMSIM3_HOME=/nfs/home/sunwenhao/XiangShan/DRAMsim3
export PATH=$NOOP_HOME/build:$PATH
export LD_LIBRARY_PATH=$NOOP_HOME/build:$LD_LIBRARY_PATH
```
同时，修改`bash_profile`为：

```
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
```

这样在加载ssh连接时，可以同步设置本地的环境变量到其他ssh节点

## 6.2 Error 255

* 问题来源：有时ssh连接超时会断
* 解决方案：设置鲁棒ssh，参考`cr-run.sh`中的鲁棒ssh选项，同时修改`./perf/server.py`，ssh断后自动重连
