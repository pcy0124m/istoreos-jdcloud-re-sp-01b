# iStoreOS 云编译 - 京东云 RE-SP-01B（MT7621）

使用 GitHub Actions 在线云编译 **iStoreOS 固件**，适配 **京东云无线宝 RE-SP-01B**（MT7621 架构，双频 WiFi + 双千兆网口 + USB）。

> ⚠️ 刷机有风险，操作前请先备份原厂固件与配置，并确认设备型号为 **RE-SP-01B**。

## ✨ 特性

- **基于官方 iStoreOS 源码**：`https://github.com/istoreos/istoreos`（默认 `istoreos-24.10` 稳定分支）
- **自动移植设备支持**：iStoreOS-24.10 分支缺少 RE-SP-01B 设备定义，仓库内置补丁 `patches/re-sp-01b.patch`，编译前自动应用（DTS / mt7621.mk / 02_network / 10_fix_wifi_mac）
- **一键云编译**：Fork 仓库 → 修改配置 → Actions 手动触发，无需本地环境
- **自定义 LAN IP 与 root 密码**：触发时可选填，首次开机自动生效
- **已精简**：移除已知问题包（samba4 / wsdd2 / diffutils 等），避免编译失败
- **产物自动发布**：编译完成后上传 Artifacts，手动触发时同时发布 GitHub Release
- **每周自动编译**：周六北京时间 02:00 定时构建

## 📦 固件默认信息

| 项目 | 默认值 |
| --- | --- |
| 管理地址 | `192.168.12.1` |
| 管理密码 | 空（无密码登录，首次使用请自行设置） |
| Web 界面 | LuCI + iStore 应用商店 |
| 默认主题 | istore / material |
| 界面语言 | 简体中文 |

## 🚀 使用方法

### 1. Fork 本仓库###1. 分叉本仓库1. 分叉本仓库1. 分叉本仓库

点击右上角 **Fork**，将仓库复制到自己的账号下。

### 2. （可选）自定义配置

- 编辑 `config/jdcloud-re-sp-01b.config` 增删软件包（如加入更多 LuCI 应用）
- 编辑 `scripts/diy1.sh` / `scripts/diy2.sh` 添加自定义脚本（feeds 前后钩子）
- 自定义开机初始化脚本放在 `files/etc/uci-defaults/` 下

### 3. 触发云编译

进入自己仓库的 **Actions** 页 → 选择 **"iStoreOS 云编译 - 京东云 RE-SP-01B"** → **Run workflow**：进入自己仓库的**Actions操作**页 → 选择**"iStoreOS 云编译 - 京东云 RE-SP-01B"** → **运行工作流**：页面 → 选择**“iStoreOS 云编译 - 京东云 RE-SP-01B”** →**运行工作流**：

| 参数 | 说明 |
| --- | --- |
| `repo_branch` | iStoreOS 源码分支/标签，默认 `istoreos-24.10` || `repo_branch` |istoreos 源码分支/标签，默认`istoreos-24.10` |
| `clean_cache` | 是否清理缓存全量编译（`true` / `false`） |
| `router_ip` | 自定义 LAN IP，如 `192.168.100.1`，留空保持默认 |
| `router_password` | 自定义 root 密码，留空则保持无密码（日志中自动隐藏） |

### 4. 下载固件

编译完成后（约 1~2 小时）：

- **Artifacts**：仓库 Actions 页面该次运行的 Artifacts，保留 14 天- **构件**：仓库 Actions 页面该次运行的 Artifacts，保留 14 天- **构件**：仓库 Actions 页面该次运行的 Artifacts，保留 14 天-**构件**：仓库 Actions 页面该次运行的 Artifacts，保留 14 天- **构件**：仓库 Actions 页面该次运行的 Artifacts，保留 14 天-**构件**：仓库 Actions 页面该次运行的 Artifacts，保留 14 天-**构件**：仓库 Actions 页面该次运行的 Artifacts，保留 14 天-**构件**：仓库 Actions 页面该次运行的 Artifacts，保留 14 天
- **Release发布发布发布发布**：手动触发时会自动创建 Release，包含 `*.bin`：手动触发时会自动创建发布，包含`*.bin` 固件与 `*.manifest` 校验文件- **发布**：手动触发时会自动创建 Release，包含`*.bin`：手动触发时会自动创建发布，包含`*.bin`：手动触发时会自动创建发布，包含`*.bin``固件与`*.manifest`校验文件- **发布**：手动触发时会自动创建 Release，包含`*.bin`：手动触发时会自动创建发布，包含`*.bin`：手动触发时会自动创建发布，包含`*.bin`：手动触发时会自动创建发布，包含`*.bin`固件与`*.manifest`校验文件-**发布**：手动触发时会自动创建 Release，包含`*.bin`固件与`*.manifest`校验文件

## 📁 目录结构

```
.
├── .github/workflows/build.yml   # GitHub Actions 云编译工作流
├── config/
│   └── jdcloud-re-sp-01b.config  # 编译配置种子（目标设备 + 软件包选择）
├── files/
│   └── etc/uci-defaults/99-custom# 首次开机初始化脚本（网络/密码/主题）
├── patches/
│   └── re-sp-01b.patch           # RE-SP-01B 设备支持补丁（从上游移植）
└── scripts/
    ├── diy1.sh                   # feeds 安装前钩子（应用设备补丁）
    └── diy2.sh                   # feeds 安装后钩子（移除问题包、合并 files）
```

## 🔧 手动编译（可选）

如果希望在本机编译，可参考以下步骤：

```bash
# 1. 克隆 iStoreOS 源码（以 istoreos-24.10 为例）
git clone --depth 1 -b istoreos-24.10 https://github.com/istoreos/istoreos openwrt
cd openwrt

# 2. 应用本仓库的脚本与配置
cp ../scripts/diy1.sh ../scripts/diy2.sh .
cp ../patches/re-sp-01b.patch .
bash diy1.sh

# 3. 更新并安装 feeds
./scripts/feeds update -a
./scripts/feeds install -a
bash diy2.sh

# 4. 写入配置并编译
cp ../config/jdcloud-re-sp-01b.config .config
make defconfig
make -j$(nproc) V=s
```

编译产物位于 `bin/targets/ramips/mt7621/`。

## ⚠️ 注意事项
刷机务必先刷initramfs-kernel.bin然后重网页固件升级上传squashfs-sysupgrade.bin不保留配置
- **设备匹配**：请确认你的设备是京东云 **RE-SP-01B**（无线宝一代），其他型号请勿刷入
- **备份**：刷机前务必用 Breed / 官方工具备份原厂固件、eeprom 与配置分区
- **首次启动**：默认 LAN IP `192.168.12.1`，如与光猫冲突请先断开光猫或使用自定义 IP
- **固件体积**：精简版固件约 22MB，适配原厂 32MB Flash 分区布局

## 📜 License##许可证

本仓库仅包含编译配置与脚本，遵循上游 OpenWrt / iStoreOS 开源协议（GPL-2.0 等）。
固件产物版权归 iStoreOS 社区及上游作者所有。
