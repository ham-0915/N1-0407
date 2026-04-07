#!/bin/bash
set -e 

# 1. 基础环境设置 (IP: 192.168.123.2 | 主机名: OpenWrt)
sed -i 's/192.168.1.1/192.168.123.2/g' package/base-files/files/bin/config_generate
sed -i 's/LEDE/OpenWrt/g' package/base-files/files/bin/config_generate

# 2. 彻底清理 feeds 冲突 (防止 PassWall, Nikki, TurboACC 等重复报错)
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls,nikki,openlist}
rm -rf feeds/luci/applications/luci-app-{passwall*,mosdns,lucky,nikki,openclash,openlist*}
rm -rf package/feeds/telephony
# 删除不需要的默认 LuCI 插件 (动态DNS、带宽监控、网络唤醒、UPnP)
rm -rf feeds/luci/applications/luci-app-ddns
rm -rf feeds/luci/applications/luci-app-nlbwmon
rm -rf feeds/luci/applications/luci-app-wol
rm -rf feeds/luci/applications/luci-app-upnp

# 3. 插件仓库拉取 (含官方 PassWall & 额外增强插件)
# PassWall 官方最新版
git clone https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages
git clone https://github.com/Openwrt-Passwall/openwrt-passwall2 package/passwall2
# SSR Plus+
git clone https://github.com/fw876/helloworld --depth=1 package/ssr-plus
# 删除 helloworld 中与 passwall-packages 重叠的依赖（以 passwall-packages 为准）
rm -rf package/ssr-plus/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}

# 常用核心插件 (Nikki, OpenClash, Lucky, MosDNS, OpenList2)
git clone https://github.com/nikkinikki-org/OpenWrt-nikki --depth=1 package/nikki
git clone https://github.com/vernesong/OpenClash --depth=1 package/openclash
git clone https://github.com/gdy666/luci-app-lucky.git --depth=1 package/lucky
git clone https://github.com/sbwml/luci-app-mosdns -b v5 --depth=1 package/mosdns
git clone https://github.com/sbwml/luci-app-openlist2 --depth=1 package/openlist2
git clone https://github.com/ophub/luci-app-amlogic --depth=1 package/amlogic

# 4. 修复系统库依赖 (防止 armsr 架构下的编译中断)
sed -i 's/REENTRANT -D_GNU_SOURCE/LARGEFILE64_SOURCE/g' feeds/packages/lang/perl/Makefile

# 5. 修正俩处错误的翻译
sed -i 's/<%:Up%>/<%:Move up%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
sed -i 's/<%:Down%>/<%:Move down%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
