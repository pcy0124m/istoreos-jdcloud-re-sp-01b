#!/bin/bash
# ============================================================
# DIY 脚本一：feeds 安装前执行
# 作用：在此处添加自定义软件源、修改默认配置等
# 工作目录：iStoreOS 源码根目录（$OPENWRTROOT）
# ============================================================
set -e

echo "================== 添加 RE-SP-01B 设备支持 =================="

# ------------------------------------------------------------
# 1. 创建 DTS 文件
# ------------------------------------------------------------
echo "创建 DTS 文件..."
cat > target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts <<'DTS_EOF'
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT

#include "mt7621.dtsi"

#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
#include <dt-bindings/leds/common.h>

/ {
	compatible = "jdcloud,re-sp-01b", "mediatek,mt7621-soc";
	model = "JDCloud RE-SP-01B";

	aliases {
		led-boot = &led_status_red;
		led-failsafe = &led_status_red;
		led-running = &led_status_green;
		led-upgrade = &led_status_blue;
	};

	chosen {
		bootargs = "console=ttyS0,115200";
	};

	keys {
		compatible = "gpio-keys";

		reset {
			label = "reset";
			gpios = <&gpio 18 GPIO_ACTIVE_LOW>;
			linux,code = <KEY_RESTART>;
		};
	};

	leds {
		compatible = "gpio-leds";

		led_status_red: led-red {
			function = LED_FUNCTION_STATUS;
			color = <LED_COLOR_ID_RED>;
			gpios = <&gpio 6 GPIO_ACTIVE_LOW>;
		};

		led_status_green: led-green {
			function = LED_FUNCTION_STATUS;
			color = <LED_COLOR_ID_GREEN>;
			gpios = <&gpio 8 GPIO_ACTIVE_LOW>;
		};

		led_status_blue: led-blue {
			function = LED_FUNCTION_STATUS;
			color = <LED_COLOR_ID_BLUE>;
			gpios = <&gpio 12 GPIO_ACTIVE_LOW>;
		};
	};
};

&sdhci {
	status = "okay";
};

&spi0 {
	status = "okay";

	flash@0 {
		compatible = "jedec,spi-nor";
		reg = <0>;
		spi-max-frequency = <50000000>;

		partitions {
			compatible = "fixed-partitions";
			#address-cells = <1>;
			#size-cells = <1>;

			partition@0 {
				label = "u-boot";
				reg = <0x0 0x30000>;
				read-only;
			};

			partition@30000 {
				label = "config";
				reg = <0x30000 0x10000>;
				read-only;
			};

			partition@40000 {
				label = "factory";
				reg = <0x40000 0x10000>;
				read-only;

				nvmem-layout {
					compatible = "fixed-layout";
					#address-cells = <1>;
					#size-cells = <1>;

					eeprom_factory_0: eeprom@0 {
						reg = <0x0 0x400>;
					};

					eeprom_factory_8000: eeprom@8000 {
						reg = <0x8000 0x4da8>;
					};
				};
			};

			partition@50000 {
				compatible = "denx,uimage";
				label = "firmware";
				reg = <0x50000 0x1ab0000>;
			};

			partition@1b00000 {
				label = "mini";
				reg = <0x1b00000 0x400000>;
				read-only;
			};

			partition@1f00000 {
				label = "oem";
				reg = <0x1f00000 0x100000>;
				read-only;
			};
		};
	};
};

&gmac0 {
	status = "okay";
	label = "lan";
	phy-mode = "rgmii";
};

&gmac1 {
	status = "okay";
	label = "wan";
	phy-handle = <&ethphy0>;
};

&ethphy0 {
	/delete-property/ interrupts;
};

&switch0 {
	ports {
		port@0 {
			status = "okay";
			label = "cpu";
		};
		port@1 {
			status = "okay";
			label = "lan1";
		};
		port@2 {
			status = "okay";
			label = "lan2";
		};
	};
};

&pcie {
	status = "okay";
};

&pcie0 {
	wifi@0,0 {
		compatible = "mediatek,mt76";
		reg = <0x0000 0 0 0 0>;
		nvmem-cells = <&eeprom_factory_0>;
		nvmem-cell-names = "eeprom";
	};
};

&state_default {
	gpio {
		groups = "uart2", "uart3", "wdt";
		function = "gpio";
	};
};
DTS_EOF
echo "DTS 文件已创建"

# ------------------------------------------------------------
# 2. 添加设备定义到 mt7621.mk
# ------------------------------------------------------------
echo "添加设备定义到 mt7621.mk..."
MT7621_MK="target/linux/ramips/image/mt7621.mk"

# 检查是否已添加
if grep -q "jdcloud_re-sp-01b" "$MT7621_MK"; then
  echo "设备定义已存在，跳过"
else
  # 在 TARGET_DEVICES += jdcloud_re-cp-02 之后添加新设备定义
  sed -i '/^TARGET_DEVICES += jdcloud_re-cp-02$/a\
\
define Device/jdcloud_re-sp-01b\
  $(Device/dsa-migration)\
  IMAGE_SIZE := 15680k\
  BLOCKSIZE := 256k\
  PAGESIZE := 4096\
  DEVICE_VENDOR := JDCloud\
  DEVICE_MODEL := RE-SP-01B\
  SUPPORTED_DEVICES += jdcloud,re-sp-01b re-sp-01b\
  DEVICE_PACKAGES := kmod-mt7603 kmod-mt7615-firmware kmod-mmc-mtk kmod-usb3\
endef\
TARGET_DEVICES += jdcloud_re-sp-01b' "$MT7621_MK"
  echo "设备定义已添加"
fi

# ------------------------------------------------------------
# 3. 添加网络配置到 02_network
# ------------------------------------------------------------
echo "添加网络配置..."
NETWORK_FILE="target/linux/ramips/mt7621/base-files/etc/board.d/02_network"

# 添加 interface setup
if grep -q "jdcloud,re-sp-01b" "$NETWORK_FILE"; then
  echo "网络配置已存在，跳过"
else
  # 在 jcg,q20 之后添加 jdcloud,re-sp-01b
  sed -i '/jcg,q20\\|/a\\	jdcloud,re-sp-01b|\\' "$NETWORK_FILE"
  
  # 添加 MAC 配置
  sed -i '/keenetic_kn-3010|\\/i\
	jdcloud,re-sp-01b)\
		lan_mac=$(mtd_get_mac_ascii config mac)\
		wan_mac=$lan_mac\
		label_mac=$lan_mac\
		;;\' "$NETWORK_FILE"
  echo "网络配置已添加"
fi

# ------------------------------------------------------------
# 4. 添加 WiFi MAC 修复
# ------------------------------------------------------------
echo "添加 WiFi MAC 修复..."
WIFI_MAC_FILE="target/linux/ramips/mt7621/base-files/etc/hotplug.d/ieee80211/10_fix_wifi_mac"

if grep -q "jdcloud,re-sp-01b" "$WIFI_MAC_FILE"; then
  echo "WiFi MAC 配置已存在，跳过"
else
  # 在 keenetic,kn-3510 之前添加
  sed -i '/keenetic,kn-3510)/i\
	jdcloud,re-sp-01b)\
		hw_mac_addr=$(mtd_get_mac_ascii config mac)\
		[ "$PHYNBR" = "0" ] && echo $hw_mac_addr > /sys${DEVPATH}/macaddress\
		[ "$PHYNBR" = "1" ] && macaddr_add $hw_mac_addr 0x800000 > /sys${DEVPATH}/macaddress\
		;;' "$WIFI_MAC_FILE"
  echo "WiFi MAC 配置已添加"
fi

# ------------------------------------------------------------
# 5. 验证
# ------------------------------------------------------------
echo "验证设备支持..."
grep -q "jdcloud_re-sp-01b" "$MT7621_MK" || {
  echo "错误：未找到 jdcloud_re-sp-01b 设备定义！"
  exit 1
}
echo "设备定义验证通过：jdcloud_re-sp-01b 已注册"

echo "================== DIY1 完成 =================="
