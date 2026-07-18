#!/bin/bash
#
# File name: diy-n1.sh
# Description: OpenWrt/Lede DIY script (feeds update 之前的内核替换 + feeds install 之后的定制)
# 说明：已合并原 diy-part1.sh + diy-part2.sh，并去除 passwall2、ssr-plus(helloworld) 相关插件

set -euo pipefail

# ------------------------------------------------------------
# 0. 内核替换（按需，默认不启用）
# ------------------------------------------------------------
#sed -i 's/KERNEL_PATCHVER:=5.15/KERNEL_PATCHVER:=5.4/g' ./target/linux/x86/Makefile

# ------------------------------------------------------------
# 1. 基础环境设置 (IP: 192.168.123.2 | 主机名: OpenWrt)
# ------------------------------------------------------------
sed -i 's/192.168.1.1/192.168.123.2/g' package/base-files/files/bin/config_generate
sed -i 's/LEDE/OpenWrt/g' package/base-files/files/bin/config_generate

# ------------------------------------------------------------
# 1.5 升级 Golang（关键稳健性修复）
#     xray-core / mosdns-v5 / hysteria / sing-box / nikki(mihomo) 等均为 Go 编写，
#     lede 官方 feeds 自带的 golang 版本经常跟不上这些包所需的最低 Go 版本，
#     社区公认解法是用 sbwml 维护的预编译 bootstrap 版本替换，避免因 Go 版本过低导致编译中断
# ------------------------------------------------------------
rm -rf feeds/packages/lang/golang
git clone --depth=1 -b 26.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang \
  || { echo "::error::克隆 packages_lang_golang 失败"; exit 1; }

# ------------------------------------------------------------
# 2. 彻底清理 feeds 冲突 (防止 PassWall, Nikki, TurboACC 等重复报错)
#    注：已去除 passwall2 / ssr-plus(helloworld) 相关内核目录
# ------------------------------------------------------------
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls,nikki,openlist}
rm -rf feeds/luci/applications/luci-app-{passwall,mosdns,lucky,nikki,openclash,openlist*}
rm -rf package/feeds/telephony
# 删除不需要的默认 LuCI 插件 (动态DNS、带宽监控、网络唤醒、UPnP)
rm -rf feeds/luci/applications/luci-app-ddns
rm -rf feeds/luci/applications/luci-app-nlbwmon
rm -rf feeds/luci/applications/luci-app-wol
rm -rf feeds/luci/applications/luci-app-upnp

# ------------------------------------------------------------
# 3. 插件仓库拉取
#    去除：openwrt-passwall2、helloworld(ssr-plus)
#    保留：passwall(主) + passwall-packages（提供内核依赖）
# ------------------------------------------------------------
git clone https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall \
  || { echo "::error::克隆 openwrt-passwall 失败"; exit 1; }
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages \
  || { echo "::error::克隆 openwrt-passwall-packages 失败"; exit 1; }

# 常用核心插件 (Nikki, OpenClash, Lucky, MosDNS, OpenList2)
git clone https://github.com/nikkinikki-org/OpenWrt-nikki --depth=1 package/nikki \
  || { echo "::error::克隆 OpenWrt-nikki 失败"; exit 1; }
git clone https://github.com/vernesong/OpenClash --depth=1 package/openclash \
  || { echo "::error::克隆 OpenClash 失败"; exit 1; }
git clone https://github.com/gdy666/luci-app-lucky.git --depth=1 package/lucky \
  || { echo "::error::克隆 luci-app-lucky 失败"; exit 1; }
git clone https://github.com/sbwml/luci-app-mosdns -b v5 --depth=1 package/mosdns \
  || { echo "::error::克隆 luci-app-mosdns 失败"; exit 1; }
git clone https://github.com/sbwml/luci-app-openlist2 --depth=1 package/openlist2 \
  || { echo "::error::克隆 luci-app-openlist2 失败"; exit 1; }
git clone https://github.com/ophub/luci-app-amlogic --depth=1 package/amlogic \
  || { echo "::error::克隆 luci-app-amlogic 失败"; exit 1; }

# 简单确认 passwall-packages 克隆成功且非空即可（具体依赖是否齐全交给
# feeds install / make defconfig 自身的依赖解析去判断，避免手动猜测目录名导致误报）
echo "::group::确认 passwall-packages 已克隆"
if [ -z "$(ls -A package/passwall-packages 2>/dev/null)" ]; then
  echo "::error::package/passwall-packages 目录为空，克隆可能未成功"
  exit 1
fi
echo "passwall-packages 目录非空，克隆确认成功"
echo "::endgroup::"

# ------------------------------------------------------------
# 4. 修复系统库依赖 (防止 armsr 架构下的编译中断)
# ------------------------------------------------------------
sed -i 's/REENTRANT -D_GNU_SOURCE/LARGEFILE64_SOURCE/g' feeds/packages/lang/perl/Makefile

# ------------------------------------------------------------
# 5. 修正俩处错误的翻译
# ------------------------------------------------------------
sed -i 's/<%:Up%>/<%:Move up%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
sed -i 's/<%:Down%>/<%:Move down%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm

# ------------------------------------------------------------
# 6. 注入 Nginx Quickfile 修复
# ------------------------------------------------------------
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-fix-nginx-quickfile << 'EOF'
#!/bin/sh
uci set nginx.global.uci_enable='true'
uci del nginx._lan; uci del nginx._redirect2ssl
uci add nginx server; uci rename nginx.@server[0]='_lan'
uci set nginx._lan.server_name='_lan'
uci add_list nginx._lan.listen='80 default_server'
uci add_list nginx._lan.listen='[::]:80 default_server'
uci add_list nginx._lan.include='conf.d/*.locations'
uci set nginx._lan.access_log='off'
uci commit nginx
/etc/init.d/nginx restart
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-fix-nginx-quickfile
