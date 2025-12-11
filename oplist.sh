#!/data/data/com.termux/files/usr/bin/bash

C_BOLD_BLUE="\033[1;34m"
C_BOLD_GREEN="\033[1;32m"
C_BOLD_YELLOW="\033[1;33m"
C_BOLD_RED="\033[1;31m"
C_BOLD_CYAN="\033[1;36m"
C_BOLD_MAGENTA="\033[1;35m"
C_BOLD_GRAY="\033[1;30m"
C_BOLD_ORANGE="\033[38;5;208m"
C_BOLD_PINK="\033[38;5;213m"
C_BOLD_LIME="\033[38;5;118m"
C_RESET="\033[0m"

INFO="${C_BOLD_BLUE}[INFO]${C_RESET}"
ERROR="${C_BOLD_RED}[ERROR]${C_RESET}"
SUCCESS="${C_BOLD_GREEN}[OK]${C_RESET}"
WARN="${C_BOLD_YELLOW}[WARN]${C_RESET}"

if [ -f "$HOME/.env" ]; then
    source "$HOME/.env"
else
    echo -e "${ERROR} 未找到 $HOME/.env 文件，请按仓库内模板配置env。"
    exit 1
fi

init_paths() {
    REAL_PATH=$(readlink -f "$0")
    SCRIPT_NAME=$(basename "$REAL_PATH")
    SCRIPT_DIR=$(dirname "$REAL_PATH")
    FILE_NAME="openlist-android-arm64.tar.gz"
    DEST_DIR="$HOME/Openlist"
    DATA_DIR="$DEST_DIR/data"
    OPENLIST_BIN="$PREFIX/bin/openlist"
    OPENLIST_LOGDIR="$DATA_DIR/log"
    OPENLIST_LOG="$OPENLIST_LOGDIR/openlist.log"
    OPENLIST_CONF="$DATA_DIR/config.json"
    ARIA2_DIR="$HOME/aria2"
    ARIA2_LOG="$ARIA2_DIR/aria2.log"
    ARIA2_CONF="$ARIA2_DIR/aria2.conf"
    ARIA2_CMD="aria2c"
    OPLIST_PATH="$PREFIX/bin/oplist"
    CACHE_DIR="$DATA_DIR/.cache"
    VERSION_CACHE="$CACHE_DIR/version.cache"
    VERSION_CHECKING="$CACHE_DIR/version.checking"
    BACKUP_DIR="/sdcard/Download"
    CONFIG_DIR="$HOME/.cloudflared"
    CF_CONFIG="$CONFIG_DIR/config.yml"
    CF_LOG="$CONFIG_DIR/tunnel.log"
}

ensure_oplist_shortcut() {
    if ! echo "$PATH" | grep -q "$PREFIX/bin"; then
        export PATH="$PATH:$PREFIX/bin"
        if ! grep -q "$PREFIX/bin" ~/.bashrc 2>/dev/null; then
            echo "export PATH=\$PATH:$PREFIX/bin" >> ~/.bashrc
        fi
        echo -e "${INFO} 已将 ${C_BOLD_YELLOW}$PREFIX/bin${C_RESET} 添加到 PATH。请重启终端确保永久生效。"
    fi
    if [ ! -f "$OPLIST_PATH" ] || [ "$REAL_PATH" != "$(readlink -f "$OPLIST_PATH")" ]; then
        if [ "$REAL_PATH" != "$OPLIST_PATH" ]; then
            cp "$REAL_PATH" "$OPLIST_PATH"
            chmod +x "$OPLIST_PATH"
            echo -e "${SUCCESS} 已将脚本安装为全局命令：${C_BOLD_YELLOW}oplist${C_RESET}"
            echo -e "${INFO} 你现在可以随时输入 ${C_BOLD_YELLOW}oplist${C_RESET} 启动管理菜单！"
            sleep 3
        fi
    fi
}

init_cache_dir() {
    [ -d "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR"
    [ -d "$BACKUP_DIR" ] || mkdir -p "$BACKUP_DIR"
    [ -d "$CONFIG_DIR" ] || mkdir -p "$CONFIG_DIR"
}

get_github_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${ERROR} .env 中未设置 GITHUB_TOKEN"
        exit 1
    fi
}

get_aria2_secret() {
    if [ -z "$ARIA2_SECRET" ]; then
        echo -e "${ERROR} .env 中未设置 ARIA2_SECRET"
        exit 1
    fi
}

get_ftp_info() {
    if [ -z "$FTP_HOST" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ] || [ -z "$FTP_PATH" ]; then
        echo -e "${ERROR} .env 中 FTP 配置不完整"
        exit 1
    fi
}

get_tunnel_info() {
    if [ -z "$TUNNEL_NAME" ] || [ -z "$DOMAIN" ] || [ -z "$LOCAL_PORT" ]; then
        echo -e "${ERROR} .env 中 Cloudflare 隧道配置不完整（需要 TUNNEL_NAME, DOMAIN, LOCAL_PORT）"
        exit 1
    fi
}

upload_to_ftp() {
    get_ftp_info
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    echo -e "${INFO} 正在上传备份 ${C_BOLD_YELLOW}$filename${C_RESET} 到 FTP 服务器 ${C_BOLD_YELLOW}ftp://$FTP_HOST$FTP_PATH${C_RESET}..."
    curl -s -T "$backup_file" "ftp://$FTP_USER:$FTP_PASS@$FTP_HOST${FTP_PATH}${filename}"
    if [ $? -eq 0 ]; then
        echo -e "${SUCCESS} 备份 ${C_BOLD_YELLOW}$filename${C_RESET} 已上传到 FTP 服务器。"
    else
        echo -e "${ERROR} 上传备份 ${C_BOLD_YELLOW}$filename${C_RESET} 失败，请检查 FTP 配置或网络。"
        return 1
    fi
    return 0
}

list_ftp_backups() {
    get_ftp_info
    local ftp_list=$(curl -s --list-only "ftp://$FTP_USER:$FTP_PASS@$FTP_HOST$FTP_PATH" | grep "backup_.*\.tar\.gz")
    if [ -z "$ftp_list" ]; then
        return 1
    fi
    echo "$ftp_list"
    return 0
}

download_ftp_backup() {
    get_ftp_info
    local filename="$1"
    local output="$BACKUP_DIR/$filename"
    echo -e "${INFO} 正在从 FTP 服务器下载 ${C_BOLD_YELLOW}$filename${C_RESET}..."
    curl -s -o "$output" "ftp://$FTP_USER:$FTP_PASS@$FTP_HOST${FTP_PATH}${filename}"
    if [ $? -eq 0 ]; then
        echo -e "${SUCCESS} 已下载备份 ${C_BOLD_YELLOW}$filename${C_RESET} 到 ${C_BOLD_YELLOW}$output${C_RESET}"
        return 0
    else
        echo -e "${ERROR} 下载备份 ${C_BOLD_YELLOW}$filename${C_RESET} 失败。"
        return 1
    fi
}

get_local_version() {
    if [ -f "$OPENLIST_BIN" ]; then
        "$OPENLIST_BIN" version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1
    fi
}

get_latest_version() {
    if [ -f "$VERSION_CACHE" ] && [ "$(find "$VERSION_CACHE" -mmin -20)" ]; then
        head -n1 "$VERSION_CACHE"
    else
        echo "检测更新中..."
    fi
}

check_version_bg() {
    if { [ ! -f "$VERSION_CACHE" ] || [ ! "$(find "$VERSION_CACHE" -mmin -20)" ]; } && [ ! -f "$VERSION_CHECKING" ]; then
        get_github_token
        touch "$VERSION_CHECKING"
        (
            curl -s -m 10 -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/OpenListTeam/OpenList/releases/latest" | \
            sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1 > "$VERSION_CACHE"
            rm -f "$VERSION_CHECKING"
        ) &
    fi
}

check_aria2_files() {
    get_aria2_secret
    mkdir -p "$ARIA2_DIR"
    if [ -d "$ARIA2_DIR/aria2.session" ]; then
        rm -rf "$ARIA2_DIR/aria2.session"
    fi
    if [ ! -f "$ARIA2_DIR/aria2.session" ]; then
        touch "$ARIA2_DIR/aria2.session"
        chmod 600 "$ARIA2_DIR/aria2.session"
    fi
    local missing_files=0
    echo -e "${INFO} 检查 aria2 相关文件..."
    if ! command -v wget >/dev/null 2>&1; then
        echo -e "${ERROR} 未检测到 wget，请先安装 wget。"
        return 1
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${ERROR} 未检测到 curl，请先安装 curl。"
        return 1
    fi
    local files=(
        "aria2.conf|https://raw.githubusercontent.com/giturass/aria2.conf/refs/heads/master/aria2.conf|600|rpc-secret=$ARIA2_SECRET"
        "clean.sh|https://raw.githubusercontent.com/giturass/aria2.conf/refs/heads/master/clean.sh|+x"
        "dht.dat|https://raw.githubusercontent.com/giturass/aria2.conf/refs/heads/master/dht.dat"
        "dht6.dat|https://raw.githubusercontent.com/giturass/aria2.conf/refs/heads/master/dht6.dat"
    )
    for file_info in "${files[@]}"; do
        IFS='|' read -r filename url perm post_process <<< "$file_info"
        local filepath="$ARIA2_DIR/$filename"
        if [ ! -f "$filepath" ]; then
            echo -e "${INFO} $filename 文件缺失，正在下载..."
            wget -q --no-check-certificate "$url" -O "$filepath"
            if [ -s "$filepath" ]; then
                if [ -n "$perm" ]; then
                    if [ "$perm" = "+x" ]; then
                        chmod +x "$filepath"
                    else
                        chmod "$perm" "$filepath"
                    fi
                fi
                if [ -n "$post_process" ]; then
                    sed -i "s|^rpc-secret=.*|$post_process|" "$filepath"
                fi
                echo -e "${SUCCESS} 已下载${perm:+并配置} $filename：${C_BOLD_YELLOW}$filepath${C_RESET}"
            else
                echo -e "${ERROR} 下载 $filename 失败，请检查网络或稍后再试。"
                rm -f "$filepath"
                missing_files=1
            fi
        fi
    done
    return $missing_files
}

create_aria2_conf() {
    if [ ! -f "$ARIA2_CONF" ]; then
        check_aria2_files
    else
        get_aria2_secret
    fi
}

setup_cloudflare_tunnel() {
    get_tunnel_info
    cd "$CONFIG_DIR" || { echo -e "${ERROR} 无法切换到 $CONFIG_DIR"; return 1; }
    if ! command -v cloudflared >/dev/null 2>&1; then
        echo -e "${INFO} cloudflared 未安装，正在安装..."
        pkg install -y cloudflared || { echo -e "${ERROR} 安装 cloudflared 失败，请检查包管理器或网络"; return 1; }
    fi
    if [ ! -f "cert.pem" ]; then
        echo -e "${INFO} 请在弹出的浏览器页面登录 Cloudflare 账号进行授权"
        echo -e "${INFO} 如果 Termux 未打开浏览器，请手动复制 URL 到浏览器"
        cloudflared tunnel login || { echo -e "${ERROR} Cloudflare 授权失败，请检查网络或稍后重试"; return 1; }
        if [ ! -f "cert.pem" ]; then
            echo -e "${ERROR} 授权后仍未生成 cert.pem 文件，请检查 Cloudflare 账户权限或重新运行 'cloudflared tunnel login'"
            return 1
        fi
    fi
    if ! cloudflared tunnel list | grep -w "$TUNNEL_NAME" >/dev/null; then
        echo -e "${INFO} 创建隧道: $TUNNEL_NAME"
        cloudflared tunnel create "$TUNNEL_NAME" || { echo -e "${ERROR} 隧道创建失败，请检查 Cloudflare 配置或网络"; return 1; }
    fi
    UUID=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}')
    if [ -z "$UUID" ]; then
        echo -e "${ERROR} 未能获取隧道 UUID，检查隧道是否创建成功"
        return 1
    fi
    CRED_FILE="$CONFIG_DIR/${UUID}.json"
    if [ ! -f "$CRED_FILE" ]; then
        echo -e "${ERROR} 隧道凭证文件 $CRED_FILE 不存在，请尝试重新创建隧道或检查权限"
        echo -e "${INFO} 你可以尝试运行：cloudflared tunnel delete -f $TUNNEL_NAME && cloudflared tunnel create $TUNNEL_NAME"
        return 1
    fi
    if [ -f "$CF_CONFIG" ]; then
        # Check if existing config is valid
        if grep -q "tunnel: $UUID" "$CF_CONFIG" && grep -q "credentials-file: $CRED_FILE" "$CF_CONFIG" && grep -q "url: http://localhost:$LOCAL_PORT" "$CF_CONFIG"; then
            echo -e "${INFO} 检测到有效的现有配置文件: $CF_CONFIG，将直接使用"
        else
            echo -e "${WARN} 现有配置文件 $CF_CONFIG 无效或与当前隧道配置不匹配，将重新生成"
            cat > "$CF_CONFIG" <<EOF
url: http://localhost:$LOCAL_PORT
tunnel: $UUID
credentials-file: $CRED_FILE
EOF
            echo -e "${SUCCESS} 配置文件已重新生成: $CF_CONFIG"
        fi
    else
        # Create new config if it doesn't exist
        cat > "$CF_CONFIG" <<EOF
url: http://localhost:$LOCAL_PORT
tunnel: $UUID
credentials-file: $CRED_FILE
EOF
        echo -e "${SUCCESS} 配置文件已生成: $CF_CONFIG"
    fi
    echo -e "${INFO} 配置 DNS 路由: $DOMAIN"
    cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN" || { echo -e "${ERROR} DNS 路由配置失败，请检查 Cloudflare 账户权限或域名配置"; return 1; }
    if pgrep -f "cloudflared.*$TUNNEL_NAME" >/dev/null; then
        echo -e "${WARN} 隧道 $TUNNEL_NAME 已在运行，尝试停止..."
        pkill -f "cloudflared.*$TUNNEL_NAME" || echo -e "${ERROR} 无法停止现有隧道进程"
        sleep 2
    fi
    echo -e "${INFO} 正在启动 Cloudflare Tunnel..."
    cloudflared tunnel --config "$CF_CONFIG" --no-autoupdate --protocol http2 run "$TUNNEL_NAME" > "$CF_LOG" 2>&1 &
    sleep 2
    if pgrep -f "cloudflared.*$TUNNEL_NAME" >/dev/null; then
        echo -e "${SUCCESS} 隧道已启动，日志输出至: $CF_LOG"
        echo -e "${INFO} 访问地址: https://$DOMAIN"
    else
        echo -e "${ERROR} 隧道启动失败，请检查 $CF_LOG 或确保 $CRED_FILE 有效"
        return 1
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
    return 0
}

stop_cloudflare_tunnel() {
    if pgrep -f "cloudflared.*$TUNNEL_NAME" >/dev/null; then
        PIDS=$(pgrep -f "cloudflared.*$TUNNEL_NAME")
        echo -e "${INFO} 检测到 Cloudflare Tunnel 正在运行，PID：${C_BOLD_YELLOW}$PIDS${C_RESET}"
        echo -e "${INFO} 正在终止 Cloudflare Tunnel..."
        pkill -f "cloudflared.*$TUNNEL_NAME"
        sleep 1
        if pgrep -f "cloudflared.*$TUNNEL_NAME" >/dev/null; then
            echo -e "${ERROR} 无法终止 Cloudflare Tunnel 进程。"
            return 1
        fi
        echo -e "${SUCCESS} Cloudflare Tunnel 已成功终止。"
    else
        echo -e "${WARN} Cloudflare Tunnel 未运行。"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
    return 0
}

tunnel_status_line() {
    if pgrep -f "cloudflared.*$TUNNEL_NAME" >/dev/null; then
        PIDS=$(pgrep -f "cloudflared.*$TUNNEL_NAME")
        echo -e "${INFO} 隧道状态：${C_BOLD_GREEN}运行中 (PID: $PIDS)${C_RESET}"
    else
        echo -e "${INFO} 隧道状态：${C_BOLD_RED}未运行${C_RESET}"
    fi
}

divider() {
    echo -e "${C_BOLD_BLUE}======================================${C_RESET}"
}

ensure_aria2() {
    if ! command -v aria2c >/dev/null 2>&1; then
        echo -e "${WARN} 未检测到 aria2，正在尝试安装..."
        if command -v pkg >/dev/null 2>&1; then
            pkg update && pkg install -y aria2
        else
            echo -e "${ERROR} 无法自动安装 aria2，请手动安装后重试。"
            exit 1
        fi
    fi
}

get_latest_url() {
    get_github_token
    curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/OpenListTeam/OpenList/releases/latest" | \
        sed -n 's/.*"browser_download_url": *"\([^"]*android-arm64\.tar\.gz\)".*/\1/p' | head -n1
}

download_with_progress() {
    url="$1"
    output="$2"
    if echo "$url" | grep -q "githubusercontent.com"; then
        get_github_token
        curl -L --progress-bar -H "Authorization: token $GITHUB_TOKEN" -o "$output" "$url"
    else
        curl -L --progress-bar -o "$output" "$url"
    fi
}

extract_file() {
    file="$1"
    tar -zxf "$file"
}

install_openlist() {
    ensure_aria2
    DOWNLOAD_URL=$(get_latest_url)
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${ERROR} 未能获取到 OpenList 安装包下载地址。"
        return 1
    fi
    cd "$SCRIPT_DIR" || { echo -e "${ERROR} 无法切换到脚本目录。"; return 1; }
    echo -e "${INFO} 正在下载 ${C_BOLD_YELLOW}$FILE_NAME${C_RESET} ..."
    download_with_progress "$DOWNLOAD_URL" "$FILE_NAME" || { echo -e "${ERROR} 下载文件失败。"; cd - >/dev/null; return 1; }
    echo -e "${INFO} 正在解压 ${C_BOLD_YELLOW}$FILE_NAME${C_RESET} ..."
    extract_file "$FILE_NAME" || { echo -e "${ERROR} 解压文件失败。"; cd - >/dev/null; return 1; }
    if [ ! -f "openlist" ]; then
        echo -e "${ERROR} 未找到 openlist 可执行文件。"; cd - >/dev/null; return 1
    fi
    mkdir -p "$DEST_DIR"
    mv -f openlist "$OPENLIST_BIN"
    chmod +x "$OPENLIST_BIN"
    rm -f "$FILE_NAME"
    echo -e "${SUCCESS} OpenList 安装完成！（已放入 $OPENLIST_BIN）"
    cd - >/dev/null
    return 0
}

update_openlist() {
    ensure_aria2
    if [ ! -d "$DEST_DIR" ]; then
        echo -e "${ERROR} ${C_BOLD_YELLOW}$DEST_DIR${C_RESET} 文件夹不存在，请先安装 OpenList。"
        return 1
    fi
    DOWNLOAD_URL=$(get_latest_url)
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${ERROR} 未能获取到 OpenList 安装包下载地址。"
        return 1
    fi
    cd "$SCRIPT_DIR" || { echo -e "${ERROR} 无法切换到脚本目录。"; return 1; }
    echo -e "${INFO} 正在下载 ${C_BOLD_YELLOW}$FILE_NAME${C_RESET} ..."
    download_with_progress "$DOWNLOAD_URL" "$FILE_NAME" || { echo -e "${ERROR} 下载文件失败。"; cd - >/dev/null; return 1; }
    echo -e "${INFO} 正在解压 ${C_BOLD_YELLOW}$FILE_NAME${C_RESET} ..."
    extract_file "$FILE_NAME" || { echo -e "${ERROR} 解压文件失败。"; cd - >/dev/null; return 1; }
    mv -f openlist "$OPENLIST_BIN"
    chmod +x "$OPENLIST_BIN"
    rm -f "$FILE_NAME"
    rm -f "$VERSION_CACHE"
    echo -e "${SUCCESS} OpenList 更新完成！"
    cd - >/dev/null
    return 0
}

check_openlist_process() {
    pgrep -f "$OPENLIST_BIN server" >/dev/null 2>&1
}

check_aria2_process() {
    pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF" >/dev/null 2>&1
}

enable_autostart_both() {
    mkdir -p "$HOME/.termux/boot"
    local boot_file="$HOME/.termux/boot/openlist_and_aria2_autostart.sh"
    cat > "$boot_file" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
ARIA2_CMD="$ARIA2_CMD"
ARIA2_CONF="$ARIA2_CONF"
\$ARIA2_CMD --conf-path="\$ARIA2_CONF" > "\$ARIA2_LOG" 2>&1 &
OPENLIST_LOG="$OPENLIST_LOG"
cd "$DATA_DIR/.." || exit 1
"$OPENLIST_BIN" server > "\$OPENLIST_LOG" 2>&1 &
EOF
    chmod +x "$boot_file"
    echo -e "${SUCCESS} OpenList 和 aria2 已成功设置开机自启"
}

disable_autostart_both() {
    local boot_file="$HOME/.termux/boot/openlist_and_aria2_autostart.sh"
    if [ -f "$boot_file" ]; then
        rm -f "$boot_file"
        echo -e "${INFO} 已禁用 OpenList 和 aria2 开机自启"
    fi
}

start_all() {
    ensure_aria2
    if [ ! -d "$DEST_DIR" ]; then
        echo -e "${ERROR} ${C_BOLD_YELLOW}$DEST_DIR${C_RESET} 文件夹不存在，请先安装 OpenList。"
        return 1
    fi
    check_aria2_files
    if [ $? -ne 0 ]; then
        echo -e "${ERROR} aria2 文件检查失败，无法启动 aria2。"
        return 1
    fi
    if check_aria2_process; then
        PIDS=$(pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF")
        echo -e "${WARN} aria2 已运行，PID：${C_BOLD_YELLOW}$PIDS${C_RESET}"
    else
        echo -e "${INFO} 启动 aria2 ..."
        $ARIA2_CMD --conf-path="$ARIA2_CONF" > "$ARIA2_LOG" 2>&1 &
        sleep 2
        ARIA2_PID=$(pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF" | head -n 1)
        if [ -n "$ARIA2_PID" ] && ps -p "$ARIA2_PID" >/dev/null 2>&1; then
            echo -e "${SUCCESS} aria2 已启动 (PID: ${C_BOLD_YELLOW}$ARIA2_PID${C_RESET})."
            echo -e "${INFO} RPC 密钥：${C_BOLD_YELLOW}$ARIA2_SECRET${C_RESET}"
        else
            echo -e "${ERROR} aria2 启动失败，继续启动 OpenList..."
        fi
    fi
    mkdir -p "$OPENLIST_LOGDIR"
    if check_openlist_process; then
        PIDS=$(pgrep -f "$OPENLIST_BIN server")
        echo -e "${WARN} OpenList server 已运行，PID：${C_BOLD_YELLOW}$PIDS${C_RESET}"
    else
        if [ ! -f "$OPENLIST_BIN" ]; then
            echo -e "${ERROR} 未找到 openlist 可执行文件。"
            return 1
        fi
        if [ ! -x "$OPENLIST_BIN" ]; then
            chmod +x "$OPENLIST_BIN"
        fi
        divider
        echo -e "${INFO} 启动 OpenList server..."
        cd "$DATA_DIR/.." || { echo -e "${ERROR} 进入 ${C_BOLD_YELLOW}$DATA_DIR/..${C_RESET} 失败。"; return 1; }
        "$OPENLIST_BIN" server > "$OPENLIST_LOG" 2>&1 &
        OPENLIST_PID=$!
        cd "$SCRIPT_DIR"
        sleep 3
        if ps -p "$OPENLIST_PID" >/dev/null 2>&1; then
            echo -e "${SUCCESS} OpenList server 已启动 (PID: ${C_BOLD_YELLOW}$OPENLIST_PID${C_RESET})."
        else
            echo -e "${ERROR} OpenList server 启动失败。"
            return 1
        fi
        if [ -f "$OPENLIST_LOG" ]; then
            PASSWORD=$(grep -oP '(?<=initial password is: )\S+' "$OPENLIST_LOG")
            if [ -n "$PASSWORD" ]; then
                echo -e "${SUCCESS} 检测到 OpenList 初始账户信息："
                echo -e "    用户名：${C_BOLD_YELLOW}admin${C_RESET}"
                echo -e "    密码：  ${C_BOLD_YELLOW}$PASSWORD${C_RESET}"
                echo -e "${INFO} 请在系统浏览器访问：${C_BOLD_YELLOW}http://localhost:5244${C_RESET}"
            else
                echo -e "${INFO} 非首次启动未在日志中找到初始密码，请使用您设置的密码。"
                echo -e "${INFO} 请在系统浏览器访问：${C_BOLD_YELLOW}http://localhost:5244${C_RESET}"
            fi
        else
            echo -e "${ERROR} 未生成 openlist.log 日志文件。"
            echo -e "${INFO} 请在系统浏览器访问：${C_BOLD_YELLOW}http://localhost:5244${C_RESET}"
        fi
        divider
    fi
    if command -v termux-wake-lock >/dev/null 2>&1; then
        termux-wake-lock
    fi
    echo -e "${C_BOLD_CYAN}是否开启 OpenList 和 aria2 开机自启？(y/n):${C_RESET}"
    read enable_boot
    if [ "$enable_boot" = "y" ] || [ "$enable_boot" = "Y" ]; then
        enable_autostart_both
    else
        disable_autostart_both
        echo -e "${INFO} 未开启开机自启。"
    fi
    divider
    return 0
}

stop_all() {
    if check_openlist_process; then
        PIDS=$(pgrep -f "$OPENLIST_BIN server")
        echo -e "${INFO} 检测到 OpenList server 正在运行，PID：${C_BOLD_YELLOW}$PIDS${C_RESET}"
        echo -e "${INFO} 正在终止 OpenList server..."
        pkill -f "$OPENLIST_BIN server"
        sleep 1
        if check_openlist_process; then
            echo -e "${ERROR} 无法终止 OpenList server 进程。"
            return 1
        fi
        echo -e "${SUCCESS} OpenList server 已成功终止。"
    else
        echo -e "${WARN} OpenList server 未运行。"
    fi
    if check_aria2_process; then
        PIDS=$(pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF")
        echo -e "${INFO} 检测到 aria2 正在运行，PID：${C_BOLD_YELLOW}$PIDS${C_RESET}"
        echo -e "${INFO} 正在终止 aria2 ..."
        pkill -f "$ARIA2_CMD --conf-path=$ARIA2_CONF"
        sleep 1
        if check_aria2_process; then
            echo -e "${ERROR} 无法终止 aria2 进程。"
            return 1
        fi
        echo -e "${SUCCESS} aria2 已成功终止。"
    else
        echo -e "${WARN} aria2 未运行。"
    fi
    return 0
}

aria2_status_line() {
    if check_aria2_process; then
        PIDS=$(pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF")
        echo -e "${INFO} aria2 状态：${C_BOLD_GREEN}运行中 (PID: $PIDS)${C_RESET}"
    else
        echo -e "${INFO} aria2 状态：${C_BOLD_RED}未运行${C_RESET}"
    fi
}

openlist_status_line() {
    if check_openlist_process; then
        PIDS=$(pgrep -f "$OPENLIST_BIN server")
        echo -e "${INFO} OpenList 状态：${C_BOLD_GREEN}运行中 (PID: $PIDS)${C_RESET}"
    else
        echo -e "${INFO} OpenList 状态：${C_BOLD_RED}未运行${C_RESET}"
    fi
}

edit_openlist_config() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 编辑 OpenList 配置文件   │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    if [ -f "$OPENLIST_CONF" ]; then
        echo -e "${INFO} 正在编辑 OpenList 配置文件：${C_BOLD_YELLOW}$OPENLIST_CONF${C_RESET}"
        vi "$OPENLIST_CONF"
        echo -e "${SUCCESS} OpenList 配置文件编辑完成。"
    else
        echo -e "${ERROR} 未找到 OpenList 配置文件：${C_BOLD_YELLOW}$OPENLIST_CONF${C_RESET}"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}

edit_aria2_config() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 编辑 aria2 配置文件      │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    if [ -f "$ARIA2_CONF" ]; then
        echo -e "${INFO} 正在编辑 aria2 配置文件：${C_BOLD_YELLOW}$ARIA2_CONF${C_RESET}"
        vi "$ARIA2_CONF"
        echo -e "${SUCCESS} aria2 配置文件编辑完成。"
    else
        echo -e "${ERROR} 未找到 aria2 配置文件：${C_BOLD_YELLOW}$ARIA2_CONF${C_RESET}"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}

view_openlist_log() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 查看 OpenList 日志       │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    if [ -f "$OPENLIST_LOG" ]; then
        echo -e "${INFO} 显示 OpenList 日志文件：${C_BOLD_YELLOW}$OPENLIST_LOG${C_RESET}"
        cat "$OPENLIST_LOG"
    else
        echo -e "${ERROR} 未找到 OpenList 日志文件：${C_BOLD_YELLOW}$OPENLIST_LOG${C_RESET}"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}

view_aria2_log() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 查看 aria2 日志          │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    if [ -f "$ARIA2_LOG" ]; then
        echo -e "${INFO} 显示 aria2 日志文件：${C_BOLD_YELLOW}$ARIA2_LOG${C_RESET}"
        cat "$ARIA2_LOG"
    else
        echo -e "${ERROR} 未找到 aria2 日志文件：${C_BOLD_YELLOW}$ARIA2_LOG${C_RESET}"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}

view_tunnel_log() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 查看 Cloudflare Tunnel 日志 │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    if [ -f "$CF_LOG" ]; then
        echo -e "${INFO} 显示 Cloudflare Tunnel 日志文件：${C_BOLD_YELLOW}$CF_LOG${C_RESET}"
        cat "$CF_LOG"
    else
        echo -e "${ERROR} 未找到 Cloudflare Tunnel 日志文件：${C_BOLD_YELLOW}$CF_LOG${C_RESET}"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}

update_bt_tracker() {
    if [ ! -f "$ARIA2_CONF" ]; then
        echo -e "${ERROR} 未找到 aria2 配置文件：${C_BOLD_YELLOW}$ARIA2_CONF${C_RESET}"
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read
        return 1
    fi
    get_github_token
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 更新 BT Tracker         │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    echo -e "${INFO} 正在更新 BT Tracker ..."
    bash <(wget --header="Authorization: token $GITHUB_TOKEN" -O - https://raw.githubusercontent.com/giturass/aria2.conf/refs/heads/master/tracker.sh) "$ARIA2_CONF"
    if [ $? -eq 0 ]; then
        echo -e "${SUCCESS} BT Tracker 更新完成！"
    else
        echo -e "${ERROR} BT Tracker 更新失败，请检查网络或 GitHub Token。"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}

update_script() {
    if [ "$SCRIPT_NAME" = "oplist" ]; then
        ORIGINAL_SCRIPT=$(find "$HOME" -name "oplist.sh" -type f 2>/dev/null | head -n 1)
        if [ -n "$ORIGINAL_SCRIPT" ]; then
            REAL_PATH="$ORIGINAL_SCRIPT"
        else
            echo -e "${ERROR} 无法找到原始脚本位置，更新失败。"
            return 1
        fi
    fi
    TMP_FILE="$SCRIPT_DIR/oplist.sh.new"
    echo -e "${INFO} 正在下载最新管理脚本..."
    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate "https://raw.githubusercontent.com/giturass/openlist_termux/main/oplist.sh" -O "$TMP_FILE"
    else
        echo -e "${ERROR} 未检测到 wget，请先安装 wget。"
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read
        return 1
    fi
    if [ -s "$TMP_FILE" ]; then
        chmod +x "$TMP_FILE"
        mv "$TMP_FILE" "$REAL_PATH"
        if [ -f "$OPLIST_PATH" ] && [ "$REAL_PATH" != "$OPLIST_PATH" ]; then
            cp "$REAL_PATH" "$OPLIST_PATH"
            chmod +x "$OPLIST_PATH"
        fi
        echo -e "${SUCCESS} 管理脚本已更新为最新版本。"
        echo -e "${INFO} 请用命令：${C_BOLD_YELLOW}oplist${C_RESET} 重新运行。"
        sleep 1
        exec "$OPLIST_PATH"
    else
        echo -e "${ERROR} 下载最新管理脚本失败，请检查网络或稍后再试。"
        rm -f "$TMP_FILE"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}

reset_openlist_password() {
    echo -e "${C_BOLD_BLUE}┌─────────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ OpenList 密码重置           │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└─────────────────────────────┘${C_RESET}"
    while true; do
        echo -ne "${C_BOLD_CYAN}请输入新密码:${C_RESET} "
        read -s pwd1
        echo
        echo -ne "${C_BOLD_CYAN}请再次输入新密码:${C_RESET} "
        read -s pwd2
        echo
        if [ "$pwd1" != "$pwd2" ]; then
            echo -e "${ERROR} 两次输入的密码不一致，请重新输入。"
        elif [ -z "$pwd1" ]; then
            echo -e "${ERROR} 密码不能为空，请重新输入。"
        else
            cd $HOME/Openlist && openlist admin set "$pwd1"
            echo -e "${SUCCESS} 密码已设置完成。"
            break
        fi
    done
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}

uninstall_all() {
    echo -e "${C_BOLD_RED}!!! 卸载将删除所有 OpenList、aria2 和 Cloudflare Tunnel 数据和配置，是否继续？(y/n):${C_RESET}"
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        pkill -f "$OPENLIST_BIN"
        pkill -f "$ARIA2_CMD"
        pkill -f "cloudflared.*$TUNNEL_NAME"
        if command -v pkg >/dev/null 2>&1; then
            pkg uninstall -y aria2 cloudflared && apt autoremove -y
        fi
        rm -rf "$DEST_DIR" "$ARIA2_DIR" "$CONFIG_DIR"
        rm -f "$HOME/oplist.sh" "$OPLIST_PATH" "$OPENLIST_BIN"
        echo -e "${SUCCESS} 已完成一键卸载。"
    else
        echo -e "${INFO} 已取消卸载。"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}

backup_restore_menu() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│    备份/还原功能         │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    echo -e "${C_BOLD_GREEN}1. 备份 Openlist 配置${C_RESET}"
    echo -e "${C_BOLD_YELLOW}2. 还原 Openlist 配置${C_RESET}"
    echo -e "${C_BOLD_GRAY}0. 返回${C_RESET}"
    echo -ne "${C_BOLD_CYAN}请选择操作 (0-2):${C_RESET} "
    read br_choice
    case $br_choice in
        1)
            local timestamp
            timestamp=$(date "+%Y%m%d_%H%M%S")
            local backup_file="$BACKUP_DIR/backup_${timestamp}.tar.gz"
            if [ ! -d "$DATA_DIR" ]; then
                echo -e "${ERROR} data 不存在，无法备份。"
            else
                if [ -d "$DATA_DIR" ]; then
                    tar -czf "$backup_file" -C "$DEST_DIR" data
                else
                    tar -czf "$backup_file" --files-from /dev/null
                fi
                echo -e "${SUCCESS} 已备份到：${C_BOLD_YELLOW}$backup_file${C_RESET}"
                upload_to_ftp "$backup_file"
            fi
            echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
            read
            ;;
        2)
            local backups=($(ls -1 "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null))
            if [ ${#backups[@]} -eq 0 ]; then
                echo -e "${WARN} 本地没有可用备份，尝试从 FTP 服务器获取..."
                ftp_backups=$(list_ftp_backups)
                if [ $? -ne 0 ] || [ -z "$ftp_backups" ]; then
                    echo -e "${WARN} FTP 服务器上没有可用备份。"
                    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
                    read
                    return
                fi
                mapfile -t ftp_backup_array <<< "$ftp_backups"
                if [ ${#ftp_backup_array[@]} -eq 0 ]; then
                    echo -e "${WARN} FTP 服务器上没有可用备份。"
                    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
                    read
                    return
                fi
                echo -e "${INFO} 可用 FTP 备份："
                local i=1
                for f in "${ftp_backup_array[@]}"; do
                    echo -e "  ${C_BOLD_YELLOW}$i.${C_RESET} $f"
                    ((i++))
                done
                echo -ne "${C_BOLD_CYAN}输入要下载的备份编号 (1-${#ftp_backup_array[@]})，或0返回:${C_RESET} "
                read sel
                if [[ ! "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt "${#ftp_backup_array[@]}" ]; then
                    echo -e "${INFO} 已取消还原。"
                    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
                    read
                    return
                fi
                local selected_backup="${ftp_backup_array[$((sel-1))]}"
                download_ftp_backup "$selected_backup"
                if [ $? -ne 0 ]; then
                    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
                    read
                    return
                fi
                backups=($(ls -1 "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null))
            fi
            if [ ${#backups[@]} -eq 0 ]; then
                echo -e "${WARN} 仍然没有可用备份。"
                echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
                read
                return
            fi
            echo -e "${INFO} 可用本地备份："
            local i=1
            for f in "${backups[@]}"; do
                echo -e "  ${C_BOLD_YELLOW}$i.${C_RESET} $(basename "$f")"
                ((i++))
            done
            echo -ne "${C_BOLD_CYAN}输入要还原的编号 (1-${#backups[@]})，或0返回:${C_RESET} "
            read sel
            if [[ ! "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt "${#backups[@]}" ]; then
                echo -e "${INFO} 已取消还原。"
                echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
                read
                return
            fi
            local restore_file="${backups[$((sel-1))]}"
            echo -e "${WARN} 这将覆盖当前 data 目录，是否继续？(y/n):${C_RESET}"
            read confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                rm -rf "$DATA_DIR"
                tar -xzf "$restore_file" -C "$DEST_DIR" data 2>/dev/null
                echo -e "${SUCCESS} 恢复完成。"
            else
                echo -e "${INFO} 已取消还原操作。"
            fi
            echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
            read
            ;;
        *)
            ;;
    esac
}

show_more_menu() {
    while true; do
        clear
        echo -e "${C_BOLD_BLUE}============= 更多功能 =============${C_RESET}"
        echo -e "${C_BOLD_GREEN}1. 修改 OpenList 密码${C_RESET}"
        echo -e "${C_BOLD_YELLOW}2. 编辑 OpenList 配置文件${C_RESET}"
        echo -e "${C_BOLD_LIME}3. 编辑 aria2 配置文件${C_RESET}"
        echo -e "${C_BOLD_CYAN}4. 更新 aria2 BT Tracker${C_RESET}"
        echo -e "${C_BOLD_MAGENTA}5. 更新管理脚本${C_RESET}"
        echo -e "${C_BOLD_RED}6. 备份/还原 Openlist 配置${C_RESET}"
        echo -e "${C_BOLD_ORANGE}7. 开启 OpenList 外网访问${C_RESET}"
        echo -e "${C_BOLD_PINK}8. 停止 OpenList 外网访问${C_RESET}"
        echo -e "${C_BOLD_LIME}9. 查看 Cloudflare Tunnel 日志${C_RESET}"
        echo -e "${C_BOLD_GRAY}0. 返回主菜单${C_RESET}"
        echo -ne "${C_BOLD_CYAN}请输入选项 (0-9):${C_RESET} "
        read sub_choice
        case $sub_choice in
            1) reset_openlist_password ;;
            2) edit_openlist_config ;;
            3) edit_aria2_config ;;
            4) update_bt_tracker ;;
            5) update_script ;;
            6) backup_restore_menu ;;
            7) setup_cloudflare_tunnel ;;
            8) stop_cloudflare_tunnel ;;
            9) view_tunnel_log ;;
            0) break ;;
            *) echo -e "${ERROR} 无效选项，请输入 0-9。"; read ;;
        esac
    done
}

show_menu() {
    clear
    echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
    echo -e "${C_BOLD_MAGENTA}         🌟 OpenList 管理菜单 🌟${C_RESET}"
    echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
    init_cache_dir
    local_ver=$(get_local_version)
    latest_ver=$(get_latest_version)
    if [ "$latest_ver" = "检测更新中..." ]; then
        ver_status="${C_BOLD_YELLOW}检测更新中...${C_RESET}"
    elif [ -z "$local_ver" ]; then
        ver_status="${C_BOLD_YELLOW}未安装${C_RESET}"
    elif [ -z "$latest_ver" ]; then
        ver_status="${C_BOLD_GREEN}已安装 $local_ver${C_RESET}"
    elif [ "$local_ver" = "$latest_ver" ]; then
        ver_status="${C_BOLD_GREEN}已是最新 $local_ver${C_RESET}"
    else
        ver_status="${C_BOLD_YELLOW}有新版 $latest_ver (当前 $local_ver)${C_RESET}"
    fi
    openlist_status_line
    aria2_status_line
    tunnel_status_line
    echo -e "${INFO} OpenList 版本：$ver_status"
    echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
    echo -e "${C_BOLD_GREEN}1. 安装 OpenList${C_RESET}"
    echo -e "${C_BOLD_YELLOW}2. 更新 OpenList${C_RESET}"
    echo -e "${C_BOLD_LIME}3. 启动 OpenList 和 aria2${C_RESET}"
    echo -e "${C_BOLD_RED}4. 停止 OpenList 和 aria2${C_RESET}"
    echo -e "${C_BOLD_ORANGE}5. 查看 OpenList 启动日志${C_RESET}"
    echo -e "${C_BOLD_PINK}6. 查看 aria2 启动日志${C_RESET}"
    echo -e "${C_BOLD_CYAN}7. 更多功能${C_RESET}"
    echo -e "${C_BOLD_GRAY}0. 退出${C_RESET}"
    echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
    echo -ne "${C_BOLD_CYAN}请输入选项 (0-7):${C_RESET} "
}

init_paths
ensure_oplist_shortcut

while true; do
    show_menu
    check_version_bg
    read choice
    case $choice in
        1) install_openlist; echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"; read ;;
        2) update_openlist; echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"; read ;;
        3) start_all; echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"; read ;;
        4) stop_all; echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"; read ;;
        5) view_openlist_log ;;
        6) view_aria2_log ;;
        7) show_more_menu ;;
        0) echo -e "${INFO} 退出程序。"; exit 0 ;;
        *) echo -e "${ERROR} 无效选项，请输入 0-7。"; echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"; read ;;
    esac
done