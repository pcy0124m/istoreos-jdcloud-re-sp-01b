#!/bin/bash
# ============================================================
# DIY 脚本二：feeds 安装后执行
# 作用：修改软件包定义、合并自定义文件、调整内核模块等
# 工作目录：iStoreOS 源码根目录（$OPENWRTROOT）
# ============================================================
set -e

# ------------------------------------------------------------
# 示例 1：调整 LuCI 主题默认顺序（iStoreOS 主题优先）
# ------------------------------------------------------------
# 在 luci-mod-admin-full 的 root 索引页面定制中可改默认主题，
# 若源码结构变化，请在此处自行适配。

# ------------------------------------------------------------
# 示例 2：从自定义路径合并文件到 rootfs
# ------------------------------------------------------------
# 在仓库根目录新建 files/ 目录，其中文件会按路径合并进固件：
#   files/etc/uci-defaults/99-custom  ->  首次启动执行脚本
#   files/etc/config/network          ->  覆盖默认网络配置
# ------------------------------------------------------------
if [ -d "$GITHUB_WORKSPACE/files" ]; then
  echo "================== 合并自定义 files/ =================="
  cp -rfv "$GITHUB_WORKSPACE/files/." package/base-files/files/
fi

# ------------------------------------------------------------
# 路由器自定义：LAN IP 和 root 密码
# 由 workflow_dispatch 输入 ROUTER_IP / ROUTER_PASSWORD 传入
# 生成 uci-defaults 脚本，固件首次启动时执行一次
# 值用 base64 编码后嵌入脚本，避免特殊字符破坏 shell 语法
# ------------------------------------------------------------
if [ -n "$ROUTER_IP" ] || [ -n "$ROUTER_PASSWORD" ]; then
  echo "================== 生成路由器自定义配置（uci-defaults） =================="
  # base64 编码（-w0 不换行；字符集仅 [A-Za-z0-9+/=]，对 sed 安全）
  IP_B64=$(printf '%s' "$ROUTER_IP" | base64 -w0 2>/dev/null || printf '%s' "$ROUTER_IP" | base64 | tr -d '\n')
  PW_B64=$(printf '%s' "$ROUTER_PASSWORD" | base64 -w0 2>/dev/null || printf '%s' "$ROUTER_PASSWORD" | base64 | tr -d '\n')
  UCI_DIR="package/base-files/files/etc/uci-defaults"
  mkdir -p "$UCI_DIR"
  cat > "$UCI_DIR/99-router-custom.sh" <<'UCISCRIPT'
#!/bin/sh
# 由 iStoreOS 云编译自动生成
# 在固件首次启动时执行一次，配置 LAN IP 和 root 密码

ROUTER_IP=$(echo "IP_PLACEHOLDER" | base64 -d 2>/dev/null)
ROUTER_PASSWORD=$(echo "PW_PLACEHOLDER" | base64 -d 2>/dev/null)

if [ -n "$ROUTER_IP" ]; then
  uci set network.lan.ipaddr="$ROUTER_IP"
  uci set network.lan.netmask='255.255.255.0'
  uci commit network
  # DHCP 地址池 start/limit 用末段相对值，会随 LAN 网段自动适配
  uci set dhcp.lan.start='100'
  uci set dhcp.lan.limit='150'
  uci commit dhcp
  echo "[router-custom] LAN IP 已设置为 $ROUTER_IP，DHCP 池：*.100-*.249"
fi

if [ -n "$ROUTER_PASSWORD" ]; then
  printf '%s\n%s\n' "$ROUTER_PASSWORD" "$ROUTER_PASSWORD" | passwd root 2>/dev/null \
    && echo "[router-custom] root 密码已设置" \
    || echo "[router-custom] root 密码设置失败，请手动 passwd"
fi

exit 0
UCISCRIPT
  chmod +x "$UCI_DIR/99-router-custom.sh"
  # 替换占位符（用 | 作 sed 分隔符避免 base64 中 / 冲突）
  sed -i "s|IP_PLACEHOLDER|$IP_B64|g" "$UCI_DIR/99-router-custom.sh"
  sed -i "s|PW_PLACEHOLDER|$PW_B64|g" "$UCI_DIR/99-router-custom.sh"
  echo "  -> LAN IP: ${ROUTER_IP:-默认（192.168.1.1）}"
  if [ -n "$ROUTER_PASSWORD" ]; then echo "  -> root 密码: 已嵌入脚本（base64 编码）"; fi
fi

# ------------------------------------------------------------
# 示例 3：调整内核选项（如开启 BBR、开启某些网络功能）
# ------------------------------------------------------------
# sed -i 's/.*CONFIG_BBR.*/CONFIG_BBR=y/' target/linux/generic/config-*

# ------------------------------------------------------------
# 示例 4：调整默认 SSID
# ------------------------------------------------------------
# sed -i 's/OpenWrt/iStoreOS/' package/network/config/wifi-scripts/files/lib/wifi/mac80211.sh

echo "================== DIY2 完成 =================="
