#!/bin/bash

# 1. 严格模式：任何命令失败立即退出，变量未定义报错
set -e
set -u

LOG_FILE="gpu_install_final.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "开始执行 GPU 环境部署"
echo "===================================================="

echo "正在停止图形界面服务..."
systemctl stop gdm3
systemctl stop gdm
systemctl stop lightdm

# 检查系统版本
OS_CODENAME=$(lsb_release -cs)

# --- 步骤 1: 基础工具 ---
echo ">>> [步骤 1/4] 安装编译环境..."
apt-get update
apt-get install -y gcc-12 g++-12 build-essential linux-headers-$(uname -r)

# --- 步骤 2: CUDA 驱动 ---
echo ">>> [步骤 2/4] 安装 CUDA 12.8..."
if ! command -v nvidia-smi &> /dev/null; then
    CUDA_RUN="cuda_12.8.0_570.86.10_linux.run"
    
    if [ ! -f "$CUDA_RUN" ]; then
        echo "正在下载 CUDA 安装包..."
        wget -q https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/$CUDA_RUN
    fi

    echo "正在执行静默安装 (请稍候)..."
    # 注意：删除了 --no-questions，使用了最通用的静默组合
    # --silent: 静默模式
    # --driver --toolkit: 安装驱动和工具箱
    # --override: 忽略 X Server 运行警告
    # --accept-license: 必须手动加上
    sh "$CUDA_RUN" --silent \
               --driver \
               --toolkit \
               --kernel-module-type=proprietary \
               --override \
               --- --no-questions --ui=none

    echo "CUDA 安装指令执行成功。"
else
    echo "检测到驱动已存在，跳过。"
fi

# --- 步骤 3: Docker ---
echo ">>> [步骤 3/4] 安装 Docker Engine..."
if ! command -v docker &> /dev/null; then
    # 彻底清理之前可能的错误源配置
    rm -f /etc/apt/sources.list.d/docker.list
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $OS_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
else
    echo "Docker 已安装，跳过。"
fi

# --- 步骤 4: Toolkit ---
echo ">>> [步骤 4/4] 配置 NVIDIA Container Toolkit..."
if ! command -v nvidia-ctk &> /dev/null; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    apt-get update
    apt-get install -y nvidia-container-toolkit
    
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
fi

echo "安装执行完毕，正在尝试重新启动图形界面..."
systemctl start gdm3
systemctl start gdm
systemctl start lightdm

echo "===================================================="
echo "所有任务已完成！"
echo "请务必执行 'sudo reboot' 重启系统以激活驱动。"
echo "===================================================="
