#!/data/data/com.termux/files/usr/bin/bash

# ========== aria2 专用模块 ==========
# 负责 aria2 的配置、启动、更新等相关操作

# 颜色定义
C_BOLD_BLUE="\033[1;34m"
C_BOLD_GREEN="\033[1;32m"
C_BOLD_YELLOW="\033[1;33m"
C_BOLD_RED="\033[1;31m"
C_BOLD_CYAN="\033[1;36m"
C_BOLD_MAGENTA="\033[1;35m"
C_BOLD_LIME="\033[38;5;118m"
C_RESET="\033[0m"

INFO="${C_BOLD_BLUE}[INFO]${C_RESET}"
ERROR="${C_BOLD_RED}[ERROR]${C_RESET}"
SUCCESS="${C_BOLD_GREEN}[OK]${C_RESET}"
WARN="${C_BOLD_YELLOW}[WARN]${C_RESET}"

get_aria2_secret() {
    if [ -z "$ARIA2_SECRET" ]; then
        echo -e "${ERROR} .env 中未设置 ARIA2_SECRET"
        exit 1
    fi
}

get_github_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${ERROR} .env 中未设置 GITHUB_TOKEN"
        exit 1
    fi
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

check_aria2_process() {
    pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF" >/dev/null 2>&1
}

enable_autostart_aria2() {
    mkdir -p "$HOME/.termux/boot"
    local boot_file="$HOME/.termux/boot/aria2_autostart.sh"
    cat > "$boot_file" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
ARIA2_CMD="$ARIA2_CMD"
ARIA2_CONF="$ARIA2_CONF"
\$ARIA2_CMD --conf-path="\$ARIA2_CONF" > "$ARIA2_LOG" 2>&1 &
EOF
    chmod +x "$boot_file"
    echo -e "${SUCCESS} aria2 已成功设置开机自启"
}

disable_autostart_aria2() {
    local boot_file="$HOME/.termux/boot/aria2_autostart.sh"
    if [ -f "$boot_file" ]; then
        rm -f "$boot_file"
        echo -e "${INFO} 已禁用 aria2 开机自启"
    fi
}

start_aria2() {
    ensure_aria2
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
            echo -e "${ERROR} aria2 启动失败。"
            return 1
        fi
    fi
    return 0
}

stop_aria2() {
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

uninstall_aria2() {
    echo -e "${C_BOLD_RED}!!! 卸载将删除所有 aria2 数据和配置，是否继续？(y/n):${C_RESET}"
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        pkill -f "$ARIA2_CMD"
        if command -v pkg >/dev/null 2>&1; then
            pkg uninstall -y aria2 && apt autoremove -y
        fi
        rm -rf "$ARIA2_DIR"
        echo -e "${SUCCESS} aria2 已完成卸载。"
    else
        echo -e "${INFO} 已取消卸载。"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
}