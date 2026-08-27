#!/bin/bash
# ============================================================
# DIY 脚本二：feeds 安装后执行
# 作用：修改软件包定义、合并自定义文件、调整内核模块等
# 工作目录：iStoreOS 源码根目录（$OPENWRTROOT）
# ============================================================
set -e

# ------------------------------------------------------------
# 关键修复：物理删除 iStoreOS 中已知有问题的包
# 这些包即使在 .config 里设为 =n，也会被其他包硬依赖拉入
# 导致编译失败（wsdd2 下载失败、diffutils 依赖缺失等）
# ------------------------------------------------------------
echo "================== 移除已知问题包 =================="
REMOVED_COUNT=0
for pkg_dir in \
  feeds/packages/net/wsdd2 \
  feeds/packages/net/samba4 \
  feeds/packages/devel/diffutils \
  feeds/packages/lang/zabbix \
  feeds/packages/lang/zsh \
  feeds/packages/devel/baresip-mod-avcodec \
  feeds/packages/devel/baresip-mod-avformat \
  feeds/packages/devel/baresip-mod-avdec \
  feeds/packages/luci/luci-app-samba4 \
  feeds/packages/luci/luci-app-wireguard \
  feeds/packages/utils/prometheus-node-exporter-ucode-wireguard
do
  if [ -d "$pkg_dir" ]; then
    echo "  移除: $pkg_dir"
    rm -rf "$pkg_dir"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
  fi
done
echo "共移除 $REMOVED_COUNT 个问题包"

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
