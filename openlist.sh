#!/data/data/com.termux/files/usr/bin/bash

# ========== OpenList 专用模块 ==========
# 负责 OpenList 的安装、启动、更新、停止等相关操作

# 颜色定义（来自主脚本）
C_BOLD_BLUE="\033[1;34m"
C_BOLD_GREEN="\033[1;32m"
C_BOLD_YELLOW="\033[1;33m"
C_BOLD_RED="\033[1;31m"
C_BOLD_CYAN="\033[1;36m"
C_BOLD_MAGENTA="\033[1;35m"
C_RESET="\033[0m"

INFO="${C_BOLD_BLUE}[INFO]${C_RESET}"
ERROR="${C_BOLD_RED}[ERROR]${C_RESET}"
SUCCESS="${C_BOLD_GREEN}[OK]${C_RESET}"
WARN="${C_BOLD_YELLOW}[WARN]${C_RESET}"

# 路径变量（继承自主脚本）

get_github_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${ERROR} .env 中未设置 GITHUB_TOKEN"
        exit 1
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
    FILE_NAME="openlist-android-arm64.tar.gz"
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
    FILE_NAME="openlist-android-arm64.tar.gz"
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

check_openlist_process() {
    pgrep -f "$OPENLIST_BIN server" >/dev/null 2>&1
}

enable_autostart_openlist() {
    mkdir -p "$HOME/.termux/boot"
    local boot_file="$HOME/.termux/boot/openlist_autostart.sh"
    cat > "$boot_file" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
OPENLIST_LOG="$OPENLIST_LOG"
cd "$DATA_DIR/.." || exit 1
"$OPENLIST_BIN" server > "\$OPENLIST_LOG" 2>&1 &
EOF
    chmod +x "$boot_file"
    echo -e "${SUCCESS} OpenList 已成功设置开机自启"
}

disable_autostart_openlist() {
    local boot_file="$HOME/.termux/boot/openlist_autostart.sh"
    if [ -f "$boot_file" ]; then
        rm -f "$boot_file"
        echo -e "${INFO} 已禁用 OpenList 开机自启"
    fi
}

start_openlist() {
    if [ ! -d "$DEST_DIR" ]; then
        echo -e "${ERROR} ${C_BOLD_YELLOW}$DEST_DIR${C_RESET} 文件夹不存在，请先安装 OpenList。"
        return 1
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
    fi
    return 0
}

stop_openlist() {
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
    return 0
}

uninstall_openlist() {
    echo -e "${C_BOLD_RED}!!! 卸载将删除所有 OpenList 数据和配置，是否继续？(y/n):${C_RESET}"
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        pkill -f "$OPENLIST_BIN"
        rm -rf "$DEST_DIR"
        rm -f "$OPENLIST_BIN"
        echo -e "${SUCCESS} OpenList 已完成卸载。"
    else
        echo -e "${INFO} 已取消卸载。"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}