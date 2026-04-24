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

git clone https://github.com/timsaya/luci-app-bandix --depth=1 package/luci-app-bandix
git clone https://github.com/timsaya/openwrt-bandix --depth=1 package/openwrt-bandix

# git clone https://github.com/sirpdboy/luci-app-timecontrol --depth=1 package/luci-app-timecontrol



# =========================================================
# 6. 动态生成 uci-defaults 脚本，首次开机自动彻底禁用 Docker
# =========================================================

echo "======== 开始执行: 动态生成禁用 Docker 脚本 ========"

# 1. 创建目录
mkdir -p package/base-files/files/etc/uci-defaults
echo "[检查] uci-defaults 目录准备完毕"

# 2. 写入防自启脚本
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-disable-docker
#!/bin/sh

/etc/init.d/dockerd disable
/etc/init.d/dockerman disable

uci set dockerd.globals.enabled='0'
uci commit dockerd

uci set dockerman.global.enabled='0'
uci commit dockerman

exit 0
EOF
echo "[成功] 99-disable-docker 脚本内容已写入"

# 3. 赋予可执行权限
chmod +x package/base-files/files/etc/uci-defaults/99-disable-docker
echo "[成功] 已赋予脚本可执行权限 (+x)"

# 4. 打印一下文件的详细信息，在日志里作为证据验证
echo ">> 查看生成的文件属性："
ls -l package/base-files/files/etc/uci-defaults/99-disable-docker

echo "======== 禁用 Docker 脚本配置完成！ ========"



