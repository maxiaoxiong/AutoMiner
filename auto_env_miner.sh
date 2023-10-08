#!/bin/bash

# 获取变量
compute=false
account=false
server=false
proxy=false
worker=false
dev_fee_on=false
opencl=false
gpus=false

# 赋值
while getopts "c:a:g:s:p:w:do" opt; do
    case "$opt" in
    c) compute="$OPTARG" ;;
    a) account="$OPTARG" ;;
    s) server=$OPTARG ;;
    p) proxy=$OPTARG ;;
    w) worker=$OPTARG ;;
    g) gpus=$OPTARG ;;
    d) dev_fee_on=true ;;
    o) opencl=true ;;
    *) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    esac
done

# 默认gpu模式运行，必须要给gpu数量
if  $gpus -lt 0 ; then
    echo "Error: gpus must specified."
    exit -1
fi

compute=$((compute / 10))

# 安装环境
apt update && apt upgrade -y
apt install git cmake make sudo -y
git clone https://github.com/shanghaicoder/XENGPUMiner.git
cd XENGPUMiner || return
chmod +x build.sh
apt install ocl-icd-opencl-dev -y
./build.sh  -cuda_arch sm_"$compute"
pip install -U -r requirements.txt
apt install screen -y
sed -i '5d' config.conf
sed -i "5i\account = $account" config.conf

# 如果设置了需要回传信息,则覆盖miner文件
if $server; then
    cp ./miner.py ../XENGPUMiner
fi


# 替换代理
if $proxy; then
    sed -i.bak "s@xenminer.mooo.com@$proxy@g" syncnode.py merkleroot.py miner.py config.conf
fi

# 默认gpu模式运行,必须要给gpu数量
for ((i = 0; i < $gpus; i++)); do
    command="./xengpuminer -d $i"
    if $opencl; then
        command+=" -m opencl"
    fi
    if [ $i -eq 0 ]; then
        screen -S "gpuminer" -dm bash -c "$command"
    else
        screen -S "gpuminer" -X screen bash -c "$command"
    fi
done
if [ $gpus -gt 0 ]; then
    echo "Running $gpus miners in GPU mode..."
fi

command="python3 miner.py"
if $dev_fee_on; then
    command+=" --dev-fee-on"
fi
if $worker; then
    command+=" --worker $worker"
fi
if $server; then
    command+=" --server $server"
fi

# 默认静默运行
screen -S submitminer -dm bash -c "$command"
echo "If you want to stop, run: pkill xengpuminer && pkill -f submitminer. or simply use pkill -f miner"
