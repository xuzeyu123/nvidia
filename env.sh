#!/bin/bash
echo "=== 禁用 Nouveau 并准备 CUDA 安装 ==="

# 禁用 nouveau
echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
sudo update-initramfs -u

# 设置命令行启动
sudo systemctl set-default multi-user.target

echo "=== 完成，请重启系统：sudo reboot ==="
echo "=== 重启后执行 CUDA 安装 ==="