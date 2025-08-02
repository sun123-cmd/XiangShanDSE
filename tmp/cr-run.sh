#!/bin/bash
########## env ##########
DIVLINE=$(perl -E "print '=' x 20")

# 设置鲁棒SSH环境
function setup_robust_ssh(){
    echo "设置鲁棒SSH环境..."
    
    # 确保SSH socket目录存在
    mkdir -p ~/.ssh/sockets
    
    # 设置SSH环境变量
    export SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
    export SSH_AGENT_PID="$SSH_AGENT_PID"
    
    # SSH连接选项
    export SSH_OPTS="-o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
    
    echo "SSH环境配置完成"
}

function set_env(){
    cd /nfs/home/sunwenhao/XiangShan
    source ./env.sh

    PERF_HOME=/nfs/home/sunwenhao/XiangShan/tmp/perf
    # 20240914-llvm18.1.8-464.h264ref-abs_tmp_inline_forarry
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
