#!/bin/bash
set -e  # 任何命令失败立即退出，防止静默跳过错误

# 1. 基础环境设置 (IP与主机名)
sed -i 's/192.168.1.1/192.168.123.2/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate

# 2. 强制升级 Golang 1.26 (编译 xray-core 26.x / sing-box 等必须)
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# 3. 彻底清理 feeds 自带的冲突项
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


# 4. 克隆 Passwall 2
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/passwall-packages
# rm -rf package/passwall-packages/shadowsocksr-libev
git clone https://github.com/Openwrt-Passwall/openwrt-passwall2.git package/passwall2


# 5. 其他插件
git clone https://github.com/ophub/luci-app-amlogic --depth=1 package/amlogic
git clone https://github.com/gdy666/luci-app-lucky --depth=1 package/lucky
git clone https://github.com/sbwml/luci-app-mosdns -b v5 --depth=1 package/mosdns
git clone https://github.com/sbwml/luci-app-openlist2 --depth=1 package/openlist2
git clone https://github.com/nikkinikki-org/OpenWrt-nikki --depth=1 package/nikki
git clone https://github.com/vernesong/OpenClash --depth=1 package/openclash
# git clone https://github.com/sirpdboy/luci-app-timecontrol --depth=1 package/luci-app-timecontrol


# 6. 修正 25.12 兼容层的按钮翻译
if [ -f feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm ]; then
    sed -i 's/<%:Up%>/<%:Move up%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
    sed -i 's/<%:Down%>/<%:Move down%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
fi



# =========================================================
# 7. Bandix 自动化集成（带严格错误检查）
# =========================================================
echo ">>> 正在启动 Bandix 集成程序..."

# 获取版本号并检查是否为空
BANDIX_FRONT_LATEST=$(curl -s "https://api.github.com/repos/timsaya/luci-app-bandix/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
BANDIX_BACK_LATEST=$(curl -s "https://api.github.com/repos/timsaya/openwrt-bandix/releases/latest" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//')

# 【新增】版本抓取失败则强制退出编译
if [ -z "$BANDIX_FRONT_LATEST" ] || [ -z "$BANDIX_BACK_LATEST" ]; then
    echo "❌ [ERROR] 无法从 GitHub 获取 Bandix 最新版本号，终止编译！"
    exit 1
fi

# 【新增】下载前端源码，失败则报错退出
git clone https://github.com/timsaya/luci-app-bandix --depth=1 -b ${BANDIX_FRONT_LATEST} package/bandix || {
    echo "❌ [ERROR] 克隆 Bandix 前端仓库失败！"
    exit 1
}

# 【新增】下载后端并存入 files 目录
mkdir -p files/root files/etc/uci-defaults
curl -L "https://github.com/timsaya/openwrt-bandix/releases/download/v${BANDIX_BACK_LATEST}/bandix_${BANDIX_BACK_LATEST}-r1_aarch64_cortex-a53.ipk" \
     -o files/root/bandix_backend.ipk || {
    echo "❌ [ERROR] 下载 Bandix 后端 IPK 失败！"
    exit 1
}

# 【新增】写入带 logger 日志记录的首次启动安装脚本
cat > files/etc/uci-defaults/99-install-bandix << 'EOF'
#!/bin/sh
if [ -f /root/bandix_backend.ipk ]; then
    logger -t "BANDIX" "开始自动安装后端核心..."
    opkg install /root/bandix_backend.ipk && rm -f /root/bandix_backend.ipk
    logger -t "BANDIX" "后端核心安装任务结束。"
fi
EOF

chmod +x files/etc/uci-defaults/99-install-bandix
echo "✅ Bandix 集成逻辑已就绪。"
