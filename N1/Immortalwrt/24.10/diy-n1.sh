#!/bin/bash
#
# diy-n1.sh — Phicomm N1 (armv8) 专用 DIY 脚本
# 执行时机：feeds update & install 完成之后，make defconfig 之前
#
set -euo pipefail
# set -e        : 任何命令非零退出立即终止
# set -u        : 引用未定义变量立即报错
# set -o pipefail : 管道中任意命令失败均视为失败

# ── 日志辅助函数 ────────────────────────────────────────────
log()  { echo ">>> $*"; }

# ============================================================
# 1. 基础设置（默认 IP / 主机名）
# ============================================================
log "设置默认 IP 与主机名"
sed -i 's/192.168.1.1/192.168.123.2/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/OpenWrt/g'       package/base-files/files/bin/config_generate

# ============================================================
# 2. 升级 Golang → 26.x
#    编译 xray-core 26.x / sing-box / naiveproxy 等必须
# ============================================================
log "替换 Golang → 26.x"
rm -rf feeds/packages/lang/golang
git clone --depth=1 -b 26.x \
  https://github.com/sbwml/packages_lang_golang \
  feeds/packages/lang/golang

# ============================================================
# 3. 清理 feeds 冲突包
# ============================================================

# ── 3a. passwall-packages 接管的代理核心，必须先删官方版本 ──
log "清理 passwall-packages 冲突的代理核心（feeds/packages/net）"
# 按字母序排列，便于日后增删核对
PASSWALL_PKGS=(
  chinadns-ng
  dns2socks
  geoview
  hysteria
  ipt2socks
  microsocks
  naiveproxy
  shadow-tls
  shadowsocks-libev
  shadowsocks-rust
  shadowsocksr-libev
  simple-obfs
  sing-box
  tcping
  trojan-plus
  tuic-client
  v2ray-geodata
  v2ray-plugin
  xray-core
  xray-plugin
)
for pkg in "${PASSWALL_PKGS[@]}"; do
  rm -rf "feeds/packages/net/$pkg"
done

# ── 3b. feeds 自带的 LuCI 插件，由后面 git clone 新版替代 ──
log "清理 feeds 自带的冲突 LuCI 插件"
rm -rf \
  feeds/luci/applications/luci-app-lucky     \
  feeds/luci/applications/luci-app-mosdns    \
  feeds/luci/applications/luci-app-nikki     \
  feeds/luci/applications/luci-app-openclash \
  feeds/luci/applications/luci-app-openlist  \
  feeds/luci/applications/luci-app-openlist2 \
  feeds/luci/applications/luci-app-passwall  \
  feeds/luci/applications/luci-app-passwall2 \
  feeds/packages/net/mosdns                  \
  feeds/packages/net/openlist

# ── 3c. 其他杂项冲突包 ──
log "清理其他杂项冲突包"
rm -rf \
  feeds/luci/luci-app-mjpg-streamer         \
  feeds/packages/admin/zabbix               \
  feeds/packages/onionshare-cli             \
  package/feeds/luci/luci-app-mjpg-streamer \
  package/feeds/packages/onionshare-cli

# 从 .config 移除已删除包的残留配置（文件不存在时静默跳过）
sed -i '/mjpg-streamer/d;/onionshare/d' .config 2>/dev/null || true

# python-ubus 路径不固定，用 find 定位后删除
find feeds/packages -type d -name "*python*ubus*" -exec rm -rf {} + 2>/dev/null || true


# ============================================================
# 4. 克隆 Passwall 2 及其代理核心依赖
#    passwall-packages 提供：xray-core / sing-box / hysteria2 /
#                            naiveproxy / tuic-client 等所有核心
# ============================================================
log "克隆 Passwall 2"
git clone --depth=1 \
  https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git \
  package/passwall-packages

git clone --depth=1 \
  https://github.com/Openwrt-Passwall/openwrt-passwall2.git \
  package/passwall2

# ============================================================
# 5. 克隆第三方插件
# ============================================================
log "克隆第三方插件"

# N1 固件在线管理
git clone --depth=1 \
  https://github.com/ophub/luci-app-amlogic        package/amlogic

# 透明代理 / DNS
git clone --depth=1 \
  https://github.com/vernesong/OpenClash            package/openclash
git clone --depth=1 \
  https://github.com/nikkinikki-org/OpenWrt-nikki   package/nikki
git clone --depth=1 -b v5 \
  https://github.com/sbwml/luci-app-mosdns          package/mosdns

# 文件管理 / 网盘
git clone --depth=1 \
  https://github.com/sbwml/luci-app-openlist2       package/openlist2
git clone --depth=1 \
  https://github.com/sbwml/luci-app-quickfile        package/luci-app-quickfile

# 工具类
git clone --depth=1 \
  https://github.com/gdy666/luci-app-lucky          package/lucky
git clone --depth=1 \
  https://github.com/timsaya/luci-app-bandix        package/luci-app-bandix
git clone --depth=1 \
  https://github.com/timsaya/openwrt-bandix         package/openwrt-bandix

# 暂不启用（保留备用，取消注释即可加入编译）
# git clone --depth=1 \
#   https://github.com/sirpdboy/luci-app-timecontrol package/luci-app-timecontrol


# ============================================================
# 6. 动态生成 Nginx 修复脚本，彻底解决 Quickfile 证书的错误
# ============================================================
log "注入 Quickfile Nginx 专属修复补丁"

# 创建标准的 uci-defaults 目录
mkdir -p package/base-files/files/etc/uci-defaults

# 动态写入 Nginx 优化脚本
cat > package/base-files/files/etc/uci-defaults/99-fix-nginx-quickfile << 'EOF'
#!/bin/sh
uci set nginx.global.uci_enable='true'
uci del nginx._lan
uci del nginx._redirect2ssl
uci add nginx server
uci rename nginx.@server[0]='_lan'
uci set nginx._lan.server_name='_lan'
uci add_list nginx._lan.listen='80 default_server'
uci add_list nginx._lan.listen='[::]:80 default_server'
uci add_list nginx._lan.include='conf.d/*.locations'
uci set nginx._lan.access_log='off'
uci commit nginx
/etc/init.d/nginx restart
exit 0
EOF

# 赋予该脚本可执行权限，确保开机能够顺利触发
chmod +x package/base-files/files/etc/uci-defaults/99-fix-nginx-quickfile

log "diy-n1.sh 全部执行完毕 ✓"
