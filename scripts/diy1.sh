#!/bin/bash
# ============================================================
# DIY 脚本一：feeds 安装前执行
# 作用：在此处添加自定义软件源、修改默认配置等
# 工作目录：iStoreOS 源码根目录（$OPENWRTROOT）
# ============================================================
set -e

# ------------------------------------------------------------
# 示例 1：添加额外的 feeds 源（取消注释即可启用）
# ------------------------------------------------------------

# 添加 iStore 应用商店扩展源
# echo "src-git istore https://github.com/linkease/istore;main" >> feeds.conf.default

# 添加 OpenWrt 官方额外源（luci、packages、routing 等）
# echo "src-git luci https://github.com/openwrt/luci.git;master" >> feeds.conf.default
# echo "src-git packages https://github.com/openwrt/packages.git;master" >> feeds.conf.default

# ------------------------------------------------------------
# 示例 2：替换默认 hostname、版本号等（按需）
# ------------------------------------------------------------

# 修改默认主机名
# sed -i 's/OpenWrt/iStoreOS/' package/base-files/files/bin/config_generate

# 修改版本号显示
# sed -i "s/DISTRIB_DESCRIPTION='OpenWrt'/DISTRIB_DESCRIPTION='iStoreOS JDCloud'/" package/base-files/files/etc/openwrt_release

echo "================== DIY1 完成 =================="
