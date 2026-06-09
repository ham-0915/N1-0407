#!/bin/bash
set -e

# ==========================================
# 1. 基础环境设置
# ==========================================
sed -i 's/192.168.1.1/192.168.123.2/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate

# ==========================================
# 2. 升级 Golang 到 26.x
# immortalwrt 24.10 自带 ~1.22，不够用
# ==========================================
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# ==========================================
# 3. 清理 feeds 冲突项（必须在 clone 新包之前）
# ==========================================
rm -rf feeds/packages/net/xray-core
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/packages/net/sing-box
rm -rf feeds/packages/net/chinadns-ng
rm -rf feeds/packages/net/dns2socks
rm -rf feeds/packages/net/hysteria
rm -rf feeds/packages/net/ipt2socks
rm -rf feeds/packages/net/microsocks
rm -rf feeds/packages/net/naiveproxy
rm -rf feeds/packages/net/shadowsocks-libev
rm -rf feeds/packages/net/shadowsocks-rust
rm -rf feeds/packages/net/shadowsocksr-libev
rm -rf feeds/packages/net/simple-obfs
rm -rf feeds/packages/net/tcping
rm -rf feeds/packages/net/trojan-plus
rm -rf feeds/packages/net/tuic-client
rm -rf feeds/packages/net/v2ray-plugin
rm -rf feeds/packages/net/xray-plugin
rm -rf feeds/packages/net/geoview
rm -rf feeds/packages/net/shadow-tls
rm -rf feeds/packages/net/redsocks2
rm -rf feeds/packages/net/dnsproxy
rm -rf feeds/packages/net/dns2tcp
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/packages/net/mosdns
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
rm -rf feeds/packages/admin/zabbix
find feeds/packages -type d -name "*python*ubus*" -exec rm -rf {} + 2>/dev/null || true
sed -i '/mjpg-streamer/d' .config 2>/dev/null || true
sed -i '/onionshare/d' .config 2>/dev/null || true

# ==========================================
# 4. Passwall 2
# ==========================================
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/passwall-packages
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall2.git package/passwall2

# ==========================================
# 5. helloworld / SSR Plus+
# ==========================================
git clone --depth=1 https://github.com/fw876/helloworld.git package/helloworld

# ==========================================
# 6. 其他插件
# ==========================================
git clone --depth=1 https://github.com/ophub/luci-app-amlogic package/amlogic
git clone --depth=1 https://github.com/gdy666/luci-app-lucky package/lucky
git clone --depth=1 -b v5 https://github.com/sbwml/luci-app-mosdns package/mosdns
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/openlist2
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki package/nikki
git clone --depth=1 https://github.com/vernesong/OpenClash package/openclash
git clone --depth=1 https://github.com/timsaya/luci-app-bandix package/luci-app-bandix
git clone --depth=1 https://github.com/timsaya/openwrt-bandix package/openwrt-bandix
git clone --depth=1 https://github.com/sbwml/luci-app-quickfile package/luci-app-quickfile

# ==========================================
# 7. 重新 feeds update/install
# 让所有手动 clone 的包进入编译索引
# ==========================================
./scripts/feeds update -a
./scripts/feeds install -a
