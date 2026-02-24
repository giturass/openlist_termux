#!/data/data/com.termux/files/usr/bin/bash

# ========== Cloudflare Tunnel 专用模块 ==========
# 负责 Cloudflare Tunnel 的配置、启动、停止等相关操作

# 颜色定义
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

get_tunnel_info() {
    if [ -z "$TUNNEL_NAME" ] || [ -z "$DOMAIN" ] || [ -z "$LOCAL_PORT" ]; then
        echo -e "${ERROR} .env 中 Cloudflare 隧道配置不完整（需要 TUNNEL_NAME, DOMAIN, LOCAL_PORT）"
        return 1
    fi
    return 0
}

setup_cloudflare_tunnel() {
    get_tunnel_info || return 1
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
        echo -e "${WARN} 隧道 $TUNNEL_NAME 已在运行，尝试停