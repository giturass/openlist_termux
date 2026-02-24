#!/data/data/com.termux/files/usr/bin/bash

# ========== 颜色定义 ==========
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

# ========== 环境初始化 ==========
if [ -f "$HOME/.env" ]; then
    source "$HOME/.env"
else
    echo -e "${ERROR} 未找到 $HOME/.env 文件，请按仓库内模板配置env。"
    exit 1
fi

# ========== 路径初始化 ==========
init_paths() {
    REAL_PATH=$(readlink -f "$0")
    SCRIPT_NAME=$(basename "$REAL_PATH")
    SCRIPT_DIR=$(dirname "$REAL_PATH")
    
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
    
    # 模块脚本路径
    OPENLIST_MODULE="$SCRIPT_DIR/openlist.sh"
    ARIA2_MODULE="$SCRIPT_DIR/aria2.sh"
    BACKUP_MODULE="$SCRIPT_DIR/backup.sh"
    TUNNEL_MODULE="$SCRIPT_DIR/tunnel.sh"
}

# ========== 快捷方式管理 ==========
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

# ========== 版本检测 ==========
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
        if [ -z "$GITHUB_TOKEN" ]; then
            return
        fi
        touch "$VERSION_CHECKING"
        (
            curl -s -m 10 -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/OpenListTeam/OpenList/releases/latest" | \
            sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1 > "$VERSION_CACHE"
            rm -f "$VERSION_CHECKING"
        ) &
    fi
}

# ========== 辅助函数 ==========
divider() {
    echo -e "${C_BOLD_BLUE}======================================${C_RESET}"
}

check_openlist_process() {
    pgrep -f "$OPENLIST_BIN server" >/dev/null 2>&1
}

check_aria2_process() {
    pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF" >/dev/null 2>&1
}

openlist_status_line() {
    if check_openlist_process; then
        PIDS=$(pgrep -f "$OPENLIST_BIN server")
        echo -e "${INFO} OpenList 状态：${C_BOLD_GREEN}运行中 (PID: $PIDS)${C_RESET}"
    else
        echo -e "${INFO} OpenList 状态：${C_BOLD_RED}未运行${C_RESET}"
    fi
}

aria2_status_line() {
    if check_aria2_process; then
        PIDS=$(pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF")
        echo -e "${INFO} aria2 状态：${C_BOLD_GREEN}运行中 (PID: $PIDS)${C_RESET}"
    else
        echo -e "${INFO} aria2 状态：${C_BOLD_RED}未运行${C_RESET}"
    fi
}

tunnel_status_line() {
    if [ -z "$TUNNEL_NAME" ]; then
        echo -e "${INFO} 隧道状态：${C_BOLD_YELLOW}未配置${C_RESET}"
        return
    fi
    if pgrep -f "cloudflared.*$TUNNEL_NAME" >/dev/null; then
        PIDS=$(pgrep -f "cloudflared.*$TUNNEL_NAME")
        echo -e "${INFO} 隧道状态：${C_BOLD_GREEN}运行中 (PID: $PIDS)${C_RESET}"
    else
        echo -e "${INFO} 隧道状态：${C_BOLD_RED}未运行${C_RESET}"
    fi
}

# ========== 脚本自更新 ==========
update_main_script() {
    if [ "$SCRIPT_NAME" = "oplist" ]; then
        ORIGINAL_SCRIPT=$(find "$HOME" -name "main.sh" -type f 2>/dev/null | head -n 1)
        if [ -n "$ORIGINAL_SCRIPT" ]; then
            REAL_PATH="$ORIGINAL_SCRIPT"
        else
            echo -e "${ERROR} 无法找到原始脚本位置，更新失败。"
            return 1
        fi
    fi
    TMP_FILE="$SCRIPT_DIR/main.sh.new"
    echo -e "${INFO} 正在下载最新管理脚本..."
    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate "https://raw.githubusercontent.com/giturass/openlist_termux/main/main.sh" -O "$TMP_FILE"
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

# ========== 启动和停止组合函数 ==========
start_all() {
    source "$OPENLIST_MODULE"
    source "$ARIA2_MODULE"
    
    # 启动 aria2
    start_aria2
    
    # 启动 OpenList
    start_openlist
    
    divider
    echo -e "${C_BOLD_CYAN}是否开启 OpenList 和 aria2 开机自启？(y/n):${C_RESET}"
    read enable_boot
    if [ "$enable_boot" = "y" ] || [ "$enable_boot" = "Y" ]; then
        enable_autostart_openlist
        enable_autostart_aria2
    else
        disable_autostart_openlist
        disable_autostart_aria2
        echo -e "${INFO} 未开启开机自启。"
    fi
    divider
    
    if command -v termux-wake-lock >/dev/null 2>&1; then
        termux-wake-lock
    fi
    return 0
}

stop_all() {
    source "$OPENLIST_MODULE"
    source "$ARIA2_MODULE"
    
    # 停止 OpenList
    stop_openlist
    
    # 停止 aria2
    stop_aria2
    
    return 0
}

# ========== 更多功能菜单 ==========
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
            1) source "$OPENLIST_MODULE"; reset_openlist_password ;;
            2) source "$OPENLIST_MODULE"; edit_openlist_config ;;
            3) source "$ARIA2_MODULE"; edit_aria2_config ;;
            4) source "$ARIA2_MODULE"; update_bt_tracker ;;
            5) update_main_script ;;
            6) source "$BACKUP_MODULE"; backup_restore_menu ;;
            7) source "$TUNNEL_MODULE"; setup_cloudflare_tunnel ;;
            8) source "$TUNNEL_MODULE"; stop_cloudflare_tunnel ;;
            9) source "$TUNNEL_MODULE"; view_tunnel_log ;;
            0) break ;;
            *) echo -e "${ERROR} 无效选项，请输入 0-9。"; read ;;
        esac
    done
}

# ========== 主菜单显示 ==========
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

# ========== 主程序流程 ==========
init_paths
ensure_oplist_shortcut

while true; do
    show_menu
    check_version_bg
    read choice
    case $choice in
        1) source "$OPENLIST_MODULE"; install_openlist; echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"; read ;;
        2) source "$OPENLIST_MODULE"; update_openlist; echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"; read ;;
        3) start_all; echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"; read ;;
        4) stop_all; echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"; read ;;
        5) source "$OPENLIST_MODULE"; view_openlist_log ;;
        6) source "$ARIA2_MODULE"; view_aria2_log ;;
        7) show_more_menu ;;
        0) echo -e "${INFO} 退出程序。"; exit 0 ;;
        *) echo -e "${ERROR} 无效选项，请输入 0-7。"; echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"; read ;;
    esac
done
