#!/bin/bash
# File name: diy-n1.sh
set -euo pipefail
# 定义 log 函数
log() {
    echo -e "\e[32m[$(date +'%Y-%m-%d %H:%M:%S')] $1\e[0m"
}

# ------------------------------------------------------------
# 1. 基础环境设置 (IP: 192.168.123.2 | 主机名: OpenWrt)
# ------------------------------------------------------------
log "设置默认 IP 与主机名"
sed -i 's/192.168.1.1/192.168.123.2/g' package/base-files/files/bin/config_generate
sed -i 's/LEDE/OpenWrt/g' package/base-files/files/bin/config_generate

# ============================================================
# Golang + lang rust
# ============================================================
log "替换 Golang → 26.x"
rm -rf feeds/packages/lang/golang
git clone --depth=1 -b 26.x https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

log "修复 lang-rust 出现404的问题"
rm -rf feeds/packages/lang/rust
git clone https://github.com/sbwml/packages_lang_rust feeds/packages/lang/rust

# ------------------------------------------------------------
# 2. 彻底清理 feeds 冲突 (防止 PassWall, Nikki, TurboACC 等重复报错)
#    注：已去除 passwall2 / ssr-plus(helloworld) 相关内核目录
# ------------------------------------------------------------
log "清理冲突包"
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls,nikki,openlist,lucky}
rm -rf feeds/luci/applications/luci-app-{passwall,mosdns,lucky,nikki,openclash,openlist*}
rm -rf package/feeds/telephony
# 删除不需要的默认 LuCI 插件 (动态DNS、带宽监控、网络唤醒、UPnP、KSM服务器)
rm -rf feeds/luci/applications/luci-app-ddns
rm -rf feeds/luci/applications/luci-app-nlbwmon
rm -rf feeds/luci/applications/luci-app-wol
rm -rf feeds/luci/applications/luci-app-upnp
rm -rf feeds/luci/applications/luci-app-vlmcsd

# ------------------------------------------------------------
# 3. 插件仓库拉取
# ------------------------------------------------------------
log "克隆第三方插件"
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/passwall-packages
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall2.git package/passwall2
git clone --depth=1 https://github.com/ophub/luci-app-amlogic package/amlogic
git clone --depth=1 https://github.com/vernesong/OpenClash package/openclash

git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki package/nikki
# ── nikki 自定义三处设置为‘不修改’ ─────────────────────────────
log "nikki: 清除默认值 log_level/ui_url/tun_stack"
sed -i "/option 'log_level' 'warning'/d" package/nikki/nikki/files/nikki.conf
sed -i "\#option 'ui_url' 'https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip'#d" package/nikki/nikki/files/nikki.conf
sed -i "/option 'tun_stack' 'mixed'/d" package/nikki/nikki/files/nikki.conf

git clone --depth=1 -b v5 https://github.com/sbwml/luci-app-mosdns package/mosdns
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/openlist2
git clone --depth=1 https://github.com/sbwml/luci-app-quickfile package/luci-app-quickfile
git clone --depth=1 https://github.com/gdy666/luci-app-lucky package/lucky
git clone --depth=1 https://github.com/timsaya/luci-app-bandix package/luci-app-bandix
git clone --depth=1 https://github.com/timsaya/openwrt-bandix package/openwrt-bandix

# ------------------------------------------------------------
# 6. 注入 Nginx Quickfile 修复
# ------------------------------------------------------------
log "注入 Nginx Quickfile 修复"
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
# ------------------------------------------------------------
log "完成 ✓"
