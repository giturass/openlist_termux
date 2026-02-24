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

get_ftp_info() {
    if [ -z "$FTP_HOST" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ] || [ -z "$FTP_PATH" ]; then
        echo -e "${ERROR} .env 中 FTP 配置不完整"
        return 1
    fi
    return 0
}

upload_to_ftp() {
    get_ftp_info || return 1
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
    get_ftp_info || return 1
    local ftp_list=$(curl -s --list-only "ftp://$FTP_USER:$FTP_PASS@$FTP_HOST$FTP_PATH" | grep "backup_.*\.tar\.gz")
    if [ -z "$ftp_list" ]; then
        return 1
    fi
    echo "$ftp_list"
    return 0
}

download_ftp_backup() {
    get_ftp_info || return 1
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

backup_openlist() {
    local timestamp
    timestamp=$(date "+%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/backup_${timestamp}.tar.gz"
    if [ ! -d "$DATA_DIR" ]; then
        echo -e "${ERROR} data 不存在，无法备份。"
        return 1
    else
        if [ -d "$DATA_DIR" ]; then
            tar -czf "$backup_file" -C "$DEST_DIR" data
        else
            tar -czf "$backup_file" --files-from /dev/null
        fi
        echo -e "${SUCCESS} 已备份到：${C_BOLD_YELLOW}$backup_file${C_RESET}"
        # 尝试上传到 FTP
        if get_ftp_info >/dev/null 2>&1; then
            upload_to_ftp "$backup_file"
        fi
        return 0
    fi
}

restore_openlist() {
    local backups=($(ls -1 "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null))
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${WARN} 本地没有可用备份，尝试从 FTP 服务器获取..."
        ftp_backups=$(list_ftp_backups)
        if [ $? -ne 0 ] || [ -z "$ftp_backups" ]; then
            echo -e "${WARN} FTP 服务器上没有可用备份。"
            echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
            read
            return 1
        fi
        mapfile -t ftp_backup_array <<< "$ftp_backups"
        if [ ${#ftp_backup_array[@]} -eq 0 ]; then
            echo -e "${WARN} FTP 服务器上没有可用备份。"
            echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
            read
            return 1
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
            return 1
        fi
        local selected_backup="${ftp_backup_array[$((sel-1))]}"
        download_ftp_backup "$selected_backup"
        if [ $? -ne 0 ]; then
            echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
            read
            return 1
        fi
        backups=($(ls -1 "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null))
    fi
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${WARN} 仍然没有可用备份。"
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read
        return 1
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
        return 1
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
    return 0
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
        1) backup_openlist ;;
        2) restore_openlist ;;
        *) ;;
    esac
}