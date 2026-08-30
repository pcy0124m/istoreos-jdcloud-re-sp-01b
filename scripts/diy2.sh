#!/bin/bash
# ============================================================
# DIY 脚本二：feeds 安装后执行
# 作用：修改软件包定义、合并自定义文件、调整内核模块等
# 工作目录：iStoreOS 源码根目录（$OPENWRTROOT）
# ============================================================
# 注意：不用 set -e，避免中途某个命令失败导致整个脚本静默退出

# ------------------------------------------------------------
# 关键修复：物理删除 iStoreOS 中已知有问题的包
# 这些包即使在 .config 里设为 =n，也会被默认包/依赖拉入。
# 注意必须同时删除两处：
#   1) feeds/ 下的源目录（包定义）
#   2) package/feeds/ 下的符号链接（feeds install 生成，
#      构建系统实际扫描的是这里，只删源目录是无效的！）
# 本步骤在"生成 .config"之前执行，删除后 defconfig 无法再选中它们
# ------------------------------------------------------------
echo "================== 移除已知问题包 =================="
REMOVED_COUNT=0
for pkg in wsdd2 samba4 diffutils luci-app-samba4; do
  # 删除 feeds 源目录（任意深度）
  while IFS= read -r d; do
    echo "  移除源目录: $d"
    rm -rf "$d"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  done < <(find feeds -type d -name "$pkg" 2>/dev/null || true)
  # 删除 package/feeds 下的符号链接/副本
  while IFS= read -r d; do
    echo "  移除包链接: $d"
    rm -rf "$d"
  done < <(find package/feeds -name "$pkg" 2>/dev/null || true)
done
echo "共移除 $REMOVED_COUNT 个问题包源目录"

# ------------------------------------------------------------
# 合并自定义 files/ 到 rootfs
# ------------------------------------------------------------
if [ -d "$GITHUB_WORKSPACE/files" ]; then
  echo "================== 合并自定义 files/ =================="
  cp -rfv "$GITHUB_WORKSPACE/files/." package/base-files/files/
fi

# ------------------------------------------------------------
# 路由器 IP/密码首次启动设置
# ------------------------------------------------------------
if [ -n "$ROUTER_IP" ] || [ -n "$ROUTER_PASSWORD" ]; then
  echo "================== 写入路由器自定义配置 =================="
  mkdir -p package/base-files/files/etc/uci-defaults
  cat > package/base-files/files/etc/uci-defaults/99-router-custom.sh << 'CUSTOM_EOF'
#!/bin/bash
# 首次启动时设置路由器 IP 和密码，之后自删除
ROUTER_IP_RAW="__ROUTER_IP__"
ROUTER_PASSWORD_B64="__ROUTER_PASSWORD_B64__"

if [ -n "$ROUTER_IP_RAW" ]; then
  uci set network.lan.ipaddr="$ROUTER_IP_RAW"
  # 同步 DHCP 地址池
  base_ip=$(echo "$ROUTER_IP_RAW" | cut -d. -f1-3)
  uci set network.lan.dhcp.limit=150
  uci set network.lan.dhcp.start=100
  uci commit network
  echo "已设置 LAN IP: $ROUTER_IP_RAW"
fi

if [ -n "$ROUTER_PASSWORD_B64" ]; then
  ROUTER_PASSWORD=$(echo "$ROUTER_PASSWORD_B64" | base64 -d 2>/dev/null)
  if [ -n "$ROUTER_PASSWORD" ]; then
    echo "root:$ROUTER_PASSWORD" | chpasswd
    echo "已设置 root 密码"
  fi
fi

# 自删除
rm -f /etc/uci-defaults/99-router-custom.sh
CUSTOM_EOF

  # 替换占位符
  sed -i "s|__ROUTER_IP__|${ROUTER_IP:-}|g" package/base-files/files/etc/uci-defaults/99-router-custom.sh
  if [ -n "$ROUTER_PASSWORD" ]; then
    PASSWORD_B64=$(echo -n "$ROUTER_PASSWORD" | base64)
    sed -i "s|__ROUTER_PASSWORD_B64__|${PASSWORD_B64}|g" package/base-files/files/etc/uci-defaults/99-router-custom.sh
  else
    sed -i "s|__ROUTER_PASSWORD_B64__||g" package/base-files/files/etc/uci-defaults/99-router-custom.sh
  fi
  chmod +x package/base-files/files/etc/uci-defaults/99-router-custom.sh
  echo "路由器自定义配置已写入"
fi

echo "================== DIY2 完成 =================="

# ------------------------------------------------------------
# RE-SP-01B 首次开机网络初始化（LAN IP + DHCP + 防火墙）
# ------------------------------------------------------------
echo "================== 写入 RE-SP-01B 网络初始化脚本 =================="
mkdir -p package/base-files/files/etc/uci-defaults

cat > package/base-files/files/etc/uci-defaults/91-net-re-sp-01b << 'RESP01B_EOF'
#!/bin/sh
# RE-SP-01B 首次开机：设置 LAN 口 IP、DHCP、桥接和防火墙
board=$(expr "$(cat /proc/sys/kernel/os_release)" : "[^_]*_([^_]*)" : '\1')

if [ "$board" = "mediatek_filogic" ] || grep -q "jdcloud,re-sp-01b\|re-sp-01b" /proc/device-tree/compatible 2>/dev/null; then
  # 确保 network 配置存在
  uci set network.lan.ipaddr='192.168.2.1'
  uci set network.lan.netmask='255.255.255.0'
  uci set network.lan.type='bridge'
  # LAN 口桥接成员兜底
  uci add_list network.lan.ifname='eth0'
  uci add_list network.lan.ifname='lan1'
  uci add_list network.lan.ifname='lan2'
  # DHCP 服务
  uci set network.lan.dhcp.limit='150'
  uci set network.lan.dhcp.start='100'
  uci set network.lan.dhcp.leasetime='12h'
  uci commit network

  # 防火墙：lan 区域
  uci set firewall.lan.network='lan'
  uci commit firewall

  echo "RE-SP-01B: LAN IP 已设为 192.168.2.1，DHCP 已启用"
fi

# 自删除
rm -f /etc/uci-defaults/91-net-re-sp-01b
RESP01B_EOF

chmod +x package/base-files/files/etc/uci-defaults/91-net-re-sp-01b
echo "RE-SP-01B 网络初始化脚本已写入"
