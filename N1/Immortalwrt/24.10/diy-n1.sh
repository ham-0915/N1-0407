#!/bin/bash
set -e  # 任何命令失败立即退出，防止静默跳过错误

# 1. 基础环境设置 (IP与主机名)
sed -i 's/192.168.1.1/192.168.123.2/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate

# 2. 强制升级 Golang 1.26 (编译 xray-core 26.x / sing-box 等必须)
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# 3. 彻底清理 feeds 自带的冲突项
# 注意：openwrt-passwall-packages 涵盖以下包，必须全部先删除避免冲突：
# chinadns-ng / dns2socks / geoview / hysteria / ipt2socks / microsocks /
# naiveproxy / shadow-tls / shadowsocks-rust / shadowsocksr-libev /
# simple-obfs / sing-box / tcping / tuic-client / v2ray-geodata /
# v2ray-plugin / xray-core / xray-plugin
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf feeds/luci/applications/luci-app-mosdns feeds/packages/net/mosdns
rm -rf feeds/packages/net/openlist
rm -rf feeds/luci/applications/luci-app-openlist
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-nikki
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-openlist2

rm -rf feeds/luci/luci-app-mjpg-streamer
rm -rf feeds/packages/onionshare-cli
rm -rf package/feeds/luci/luci-app-mjpg-streamer
rm -rf package/feeds/packages/onionshare-cli
sed -i '/mjpg-streamer/d' .config 2>/dev/null || true
sed -i '/onionshare/d' .config 2>/dev/null || true
rm -rf feeds/packages/admin/zabbix
find feeds/packages -type d -name "*python*ubus*" -exec rm -rf {} +

# 同时清理 feeds install 阶段产生 WARNING 的无用包
# 说明：这些包是 ImmortalWrt 官方 feeds 自带的，与 N1/armv8 无关，
#       或依赖了编译环境中不存在的库，删除后可消除 feeds install 时的 WARNING。
#       不影响任何你实际需要的功能。
#
# audit        - 依赖 libev，N1 用不到审计框架
# autocore     - 依赖 lm-sensors，该库仅 x86 有，armv8 无温度传感器支持
# autosamba    - 依赖 luci-app-samba4/wsdd2，与你手动加的 samba4 冲突且功能重叠
# kexec-tools  - 依赖 liblzma，内核热重启工具，N1 固件用不到
# lldpd        - 依赖 libnetsnmp，链路层发现协议，家用场景无需 SNMP 扩展
# pcat-manager - 依赖 glib2/libgpiod，PCAT 专属硬件管理，与 N1 无关
# policycoreutils - 依赖 libpam，SELinux 管理工具，OpenWrt 默认不启用 SELinux
rm -rf feeds/packages/utils/audit
rm -rf feeds/packages/emortal/autocore
rm -rf feeds/packages/emortal/autosamba
rm -rf feeds/packages/boot/kexec-tools
rm -rf feeds/packages/network/services/lldpd
rm -rf feeds/packages/utils/pcat-manager
rm -rf feeds/packages/utils/policycoreutils


# 4. 克隆 Passwall 2 及其依赖包
# passwall-packages 提供所有代理核心：xray-core/sing-box/hysteria2/naiveproxy/tuic-client 等
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/passwall-packages
git clone https://github.com/Openwrt-Passwall/openwrt-passwall2.git package/passwall2


# 5. 其他插件
git clone https://github.com/ophub/luci-app-amlogic --depth=1 package/amlogic
git clone https://github.com/gdy666/luci-app-lucky --depth=1 package/lucky
git clone https://github.com/sbwml/luci-app-mosdns -b v5 --depth=1 package/mosdns
git clone https://github.com/sbwml/luci-app-openlist2 --depth=1 package/openlist2
git clone https://github.com/nikkinikki-org/OpenWrt-nikki --depth=1 package/nikki
git clone https://github.com/vernesong/OpenClash --depth=1 package/openclash
git clone https://github.com/timsaya/luci-app-bandix --depth=1 package/luci-app-bandix
git clone https://github.com/timsaya/openwrt-bandix --depth=1 package/openwrt-bandix
git clone https://github.com/sbwml/luci-app-quickfile --depth=1 package/luci-app-quickfile

# git clone https://github.com/sirpdboy/luci-app-timecontrol --depth=1 package/luci-app-timecontrol

