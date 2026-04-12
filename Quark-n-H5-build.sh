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

# ARM 交叉工具链：仓库内为压缩包，首次使用前解压到 tools/15.2.rel1-arm64
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/../tools"
TOOLCHAIN_DIR="$TOOLS_DIR/15.2.rel1-arm64"
ARCHIVE="$TOOLS_DIR/arm-gnu-toolchain-15.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz"
GCC_LOCAL="$TOOLCHAIN_DIR/bin/aarch64-none-linux-gnu-gcc"

if [[ -x "$GCC_LOCAL" ]]; then
    if [[ ":$PATH:" != *":$TOOLCHAIN_DIR/bin:"* ]]; then
        echo "检测到已解压的本地工具链，正在加入 PATH..."
        export PATH="$TOOLCHAIN_DIR/bin:$PATH"
    fi
elif command -v aarch64-none-linux-gnu-gcc >/dev/null 2>&1; then
    echo "已检测到 PATH 中的 aarch64-none-linux-gnu-gcc，跳过解压。"
else
    if [[ ! -f "$ARCHIVE" ]]; then
        echo "错误：未找到工具链压缩包，请将以下文件放入仓库后再编译：" >&2
        echo "  $ARCHIVE" >&2
        exit 1
    fi
    echo "正在解压 ARM GNU 工具链到 $TOOLCHAIN_DIR ..."
    mkdir -p "$TOOLCHAIN_DIR"
    if ! tar -xJf "$ARCHIVE" -C "$TOOLCHAIN_DIR" --strip-components=1; then
        echo "错误：解压失败，请确认系统 tar 支持 xz（-J），且压缩包完整。" >&2
        exit 1
    fi
    if [[ ! -x "$GCC_LOCAL" ]]; then
        echo "错误：解压后未找到预期编译器: $GCC_LOCAL" >&2
        echo "若压缩包顶层目录结构与官方包不一致，请检查包内路径并调整 --strip-components。" >&2
        exit 1
    fi
    export PATH="$TOOLCHAIN_DIR/bin:$PATH"
fi

export GCC_COLORS=auto

echo "========================================="
echo "GCC 交叉编译环境"
echo "========================================="
if [[ -x "$GCC_LOCAL" ]]; then
    echo "工具链路径: $TOOLCHAIN_DIR/bin"
elif command -v arm-none-linux-gnueabihf-gcc >/dev/null 2>&1; then
    echo "使用 PATH 中的: $(command -v aarch64-none-linux-gnu-gcc)"
fi
echo "GCC_COLORS=auto"
echo ""
echo "测试 GCC 版本："
aarch64-none-linux-gnu-gcc -v 2>&1 | head -n 5
echo ""
echo "可以开始编译 u-boot"
echo "========================================="
echo ""

make clean

export BL31=$(pwd)/../arm-trusted-firmware-master/build/sun50i_a64/release/bl31.bin

export SCP=$(pwd)/../crust/build/scp/scp.bin

make quark-luoorshi-h5_defconfig  ARCH=arm CROSS_COMPILE=aarch64-none-linux-gnu-

make ARCH=arm CROSS_COMPILE=aarch64-none-linux-gnu- V=1 -j4 2>&1 | tee build.log

make ARCH=arm CROSS_COMPILE=aarch64-none-linux-gnu- -j4 2>&1 | tee build.log


