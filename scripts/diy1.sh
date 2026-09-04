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

# ------------------------------------------------------------
# 集成 OpenAppFilter（OAF 应用过滤）
# 固定 v6.1.8 稳定版（官方支持 OpenWrt 24.10 / kernel 6.6）
# 注意：自编译固件无法用 opkg 安装官方 OAF（内核 magic 不匹配），
#       必须随固件源码一起编译。
# ------------------------------------------------------------
echo "================== 集成 OpenAppFilter (v6.1.8) =================="
if [ ! -d package/OpenAppFilter ]; then
  git clone --depth 1 --branch v6.1.8 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter
fi
[ -d package/OpenAppFilter/oaf ] && [ -d package/OpenAppFilter/open-app-filter ] && [ -d package/OpenAppFilter/luci-app-oaf ] || {
  echo "错误：OpenAppFilter 克隆不完整！"
  exit 1
}
echo "OpenAppFilter 已就位：$(ls -d package/OpenAppFilter/*/)"

# ------------------------------------------------------------
# 应用京东云 RE-SP-01B 设备支持补丁
# iStoreOS-24.10 分支缺少该设备定义（OpenWrt 上游 commit
# c35f2a23 才加入），此处从上游移植，包含：
#   - DTS:  target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts
#   - 固件定义: target/linux/ramips/image/mt7621.mk
#   - 网络/MAC: base-files board.d/02_network + hotplug.d/10_fix_wifi_mac
# 该补丁基于 istoreos-24.10 真实源码生成并本地验证可干净应用
# 必须在 clone 之后、生成 .config 之前应用，种子 config 中的
# CONFIG_TARGET_..._DEVICE_jdcloud_re-sp-01b 才能匹配到设备定义
# ------------------------------------------------------------
echo "================== 应用 RE-SP-01B 设备支持补丁 =================="
PATCH="$GITHUB_WORKSPACE/patches/re-sp-01b.patch"
if [ ! -f "$PATCH" ]; then
  echo "错误：补丁不存在: $PATCH"
  exit 1
fi
git apply --check "$PATCH" || { echo "错误：补丁检查失败"; exit 1; }
git apply "$PATCH"
echo "已应用: re-sp-01b.patch"

# 验证设备定义已就位（失败则中止，避免编出错误设备的固件）
grep -q "^TARGET_DEVICES += jdcloud_re-sp-01b$" target/linux/ramips/image/mt7621.mk || {
  echo "错误：补丁应用后未找到 jdcloud_re-sp-01b 设备定义！"
  exit 1
}
grep -q "jdcloud,re-sp-01b" target/linux/ramips/mt7621/base-files/etc/board.d/02_network || {
  echo "错误：02_network 缺少 jdcloud,re-sp-01b 配置！"
  exit 1
}
grep -q "jdcloud,re-sp-01b" target/linux/ramips/mt7621/base-files/etc/hotplug.d/ieee80211/10_fix_wifi_mac || {
  echo "错误：10_fix_wifi_mac 缺少 jdcloud,re-sp-01b 配置！"
  exit 1
}
[ -f target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts ] || {
  echo "错误：DTS 文件不存在！"
  exit 1
}
echo "设备定义验证通过：DTS / mt7621.mk / 02_network / 10_fix_wifi_mac 全部就位"

echo "================== DIY1 完成 =================="
