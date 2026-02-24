#!/data/data/com.termux/files/usr/bin/bash

# ========== 备份还原专用模块 ==========
# 负责备份和还原 OpenList 配置

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

# ========== 环境加载 ==========
if [ -f "$HOME/.env" ]; then
    source "$HOME/.env"
fi

# ========== 备份 OpenList ==========
backup_openlist() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│    备份 OpenList 配��    │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    echo ""
    
    local timestamp
    timestamp=$(date "+%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/backup_${timestamp}.tar.gz"
    
    if [ ! -d "$DATA_DIR" ]; then
        echo -e "${ERROR} data 目录不存在，无法备份。"
        echo ""
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read
        return 1
    fi
    
    echo -e "${INFO} 正在备份 OpenList 配置..."
    echo -e "${INFO} 备份路径：${C_BOLD_YELLOW}$backup_file${C_RESET}"
    echo ""
    
    if tar -czf "$backup_file" -C "$DEST_DIR" data 2>/dev/null; then
        local file_size=$(du -h "$backup_file" | cut -f1)
        echo -e "${SUCCESS} ✓ 备份成功！"
        echo -e "${INFO} 文件大小：${C_BOLD_YELLOW}$file_size${C_RESET}"
        echo -e "${INFO} 保存位置：${C_BOLD_YELLOW}$backup_file${C_RESET}"
    else
        echo -e "${ERROR} ✗ 备份失败，请检查磁盘空间或权限。"
        rm -f "$backup_file"
        echo ""
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read
        return 1
    fi
    
    echo ""
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
    return 0
}

# ========== 还原 OpenList ==========
restore_openlist() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│    还原 OpenList 配置    │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    echo ""
    
    local backups=($(ls -1t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${WARN} 本地没有可用备份。"
        echo -e "${INFO} 备份目录：${C_BOLD_YELLOW}$BACKUP_DIR${C_RESET}"
        echo ""
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read
        return 1
    fi
    
    echo -e "${INFO} 找到 ${#backups[@]} 个本地备份"
    echo ""
    
    local i=1
    for f in "${backups[@]}"; do
        local file_size=$(du -h "$f" | cut -f1)
        local file_time=$(stat -c %y "$f" | cut -d' ' -f1,2)
        echo -e "  ${C_BOLD_YELLOW}$i.${C_RESET} $(basename "$f")"
        echo -e "     └─ ${file_size} | ${file_time}"
        ((i++))
    done
    
    echo ""
    echo -ne "${C_BOLD_CYAN}输入要还原的备份编号 (1-${#backups[@]})，或按 0 返回:${C_RESET} "
    read sel
    
    if [[ ! "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt "${#backups[@]}" ]; then
        echo -e "${INFO} 已取消还原。"
        echo ""
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read
        return 1
    fi
    
    local restore_file="${backups[$((sel-1))]}"
    local restore_name=$(basename "$restore_file")
    
    echo ""
    echo -e "${WARN} ⚠️  还原将覆盖当前所有 OpenList 数据！"
    echo -e "${INFO} 选择备份：${C_BOLD_YELLOW}$restore_name${C_RESET}"
    echo ""
    echo -ne "${C_BOLD_RED}确定继续吗？(y/n):${C_RESET} "
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${INFO} 已取消还原。"
        echo ""
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read
        return 1
    fi
    
    echo ""
    echo -e "${INFO} 正在还原备份..."
    
    rm -rf "$DATA_DIR"
    if tar -xzf "$restore_file" -C "$DEST_DIR" 2>/dev/null; then
        echo -e "${SUCCESS} ✓ 还原成功！"
        echo -e "${INFO} OpenList 配置已还原完成。"
    else
        echo -e "${ERROR} ✗ 还原失败！"
        echo -e "${ERROR} 请检查备份文件是否损坏。"
        echo ""
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read
        return 1
    fi
    
    echo ""
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read
    return 0
}

# ========== 备份还原菜单 ==========
backup_restore_menu() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│    备份/还原功能         │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    echo ""
    echo -e "${C_BOLD_GREEN}1. 备份 OpenList 配置${C_RESET}"
    echo -e "${C_BOLD_YELLOW}2. 还原 OpenList 配置${C_RESET}"
    echo -e "${C_BOLD_GRAY}0. 返回${C_RESET}"
    echo ""
    echo -ne "${C_BOLD_CYAN}请选择操作 (0-2):${C_RESET} "
    read br_choice
    case $br_choice in
        1) backup_openlist ;;
        2) restore_openlist ;;
        *) ;;
    esac
}
