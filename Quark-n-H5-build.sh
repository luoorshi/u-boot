#!/bin/bash

# 检查必需的编译工具
missing_tools=()

if ! command -v gcc &> /dev/null; then
    missing_tools+=("gcc")
fi

if ! command -v bison &> /dev/null; then
    missing_tools+=("bison")
fi

if ! command -v flex &> /dev/null; then
    missing_tools+=("flex")
fi

if [ ${#missing_tools[@]} -gt 0 ]; then
    echo "========================================="
    echo "警告：系统缺少必需的编译工具"
    echo "========================================="
    echo "缺少的工具: ${missing_tools[*]}"
    echo ""
    echo "请执行以下命令安装："
    echo "  sudo apt update"
    echo "  sudo apt install -y gcc build-essential bison flex"
    echo ""
    echo "或者安装完整的编译环境："
    echo "  sudo apt install -y git openssh-server"
    echo "  sudo apt install -y make make-guile"
    echo "  sudo apt install -y swig python-dev python3-dev bison flex python3-distutils"
    echo "  sudo apt-get install -y lsb-core"
    echo "  sudo apt-get install -y lib32stdc++6"
    echo "  sudo apt-get install -y libssl-dev"
    echo "  sudo apt-get install -y openssl"
    echo "========================================="
    echo ""
    echo "注意：编译可能会失败，请先安装缺少的工具"
    echo "========================================="
    echo ""
fi

# 检查是否已经设置了GCC环境变量
if [[ ":$PATH:" != *"tools/15.2.rel1-arm64/bin:"* ]]; then
    echo "检测到未设置GCC交叉编译环境变量，正在设置..."
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 设置GCC工具链路径
    export PATH="$SCRIPT_DIR/tools/15.2.rel1-arm64/bin:$PATH"
    export GCC_COLORS=auto

    # 显示当前环境变量
    echo "========================================="
    echo "GCC交叉编译环境已设置"
    echo "========================================="
    echo "GCC工具链路径: $SCRIPT_DIR/tools/15.2.rel1-arm64/bin"
    echo "GCC_COLORS=auto"
    echo ""
    echo "测试GCC版本："
    aarch64-none-linux-gnu-gcc -v 2>&1 | head -n 5
    echo ""
    echo "环境变量已设置，可以开始编译u-boot"
    echo "========================================="
    echo ""
fi

make clean

export BL31=$(pwd)/../arm-trusted-firmware-master/build/sun50i_a64/release/bl31.bin
export SCP=$(pwd)/../crust/build/scp/scp.bin

make quark-luoorshi-h5_defconfig  ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu-

make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- V=1 -j4 2>&1 | tee build.log

make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- -j4 2>&1 | tee build.log


