#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m'

INFO="${BLUE}[INFO]${NC}"
ERROR="${RED}[ERROR]${NC}"
SUCCESS="${GREEN}[OK]${NC}"
WARN="${YELLOW}[WARN]${NC}"

FILE_NAME="openlist-android-arm64.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$SCRIPT_DIR/Openlist"
OPENLIST_LOGDIR="$DEST_DIR/data/log"
OPENLIST_LOG="$OPENLIST_LOGDIR/openlist.log"
ARIA2_DIR="$SCRIPT_DIR/aria2"
ARIA2_LOG="$ARIA2_DIR/aria2.log"
ARIA2_CMD="aria2c"

get_latest_url() {
  curl -s https://api.github.com/repos/OpenListTeam/OpenList/releases/latest \
    | grep "browser_download_url" \
    | grep "openlist-android-arm64.tar.gz" \
    | cut -d '"' -f 4
}

divider() { echo -e "${YELLOW}------------------------------------------------------------${NC}"; }

ensure_tools() {
  for tool in curl aria2c; do
    if ! command -v $tool >/dev/null 2>&1; then
      echo -e "${WARN} 未检测到 $tool，正在尝试安装..."
      if command -v apt >/dev/null 2>&1; then
        apt update && apt install -y $tool
      elif command -v pkg >/dev/null 2>&1; then
        pkg update && pkg install -y $tool
      else
        echo -e "${ERROR} 无法自动安装 $tool，请手动安装后重试。"
        exit 1
      fi
    fi
  done
}

download_with_progress() {
  local url="$1"
  local output="$2"
  curl -L --progress-bar -o "$output" "$url"
}

extract_file() {
  local file="$1"
  tar -zxf "$file"
}

install_openlist() {
  ensure_tools
  local DOWNLOAD_URL
  DOWNLOAD_URL=$(get_latest_url)
  if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${ERROR} 未能获取到最新 OpenList 安装包下载地址。"
    return 1
  fi
  pushd "$SCRIPT_DIR" > /dev/null || { echo -e "${ERROR} 无法切换到脚本目录。"; return 1; }
  echo -e "${INFO} 正在下载 ${YELLOW}$FILE_NAME${NC} ..."
  download_with_progress "$DOWNLOAD_URL" "$FILE_NAME" || { echo -e "${ERROR} 下载文件失败。"; popd > /dev/null; return 1; }
  echo -e "${INFO} 正在解压 ${YELLOW}$FILE_NAME${NC} ..."
  extract_file "$FILE_NAME" || { echo -e "${ERROR} 解压文件失败。"; popd > /dev/null; return 1; }
  [ ! -f "openlist" ] && { echo -e "${ERROR} 未找到 openlist 可执行文件。"; popd > /dev/null; return 1; }
  echo -e "${INFO} 创建文件夹 ${YELLOW}$DEST_DIR${NC} ..."
  mkdir -p "$DEST_DIR"
  mv -f openlist "$DEST_DIR/" || { echo -e "${ERROR} 移动 openlist 文件失败。"; popd > /dev/null; return 1; }
  chmod +x "$DEST_DIR/openlist"
  rm -f "$FILE_NAME"
  echo -e "${SUCCESS} OpenList 安装完成！"
  popd > /dev/null
  return 0
}

update_openlist() {
  ensure_tools
  [ ! -d "$DEST_DIR" ] && { echo -e "${ERROR} $DEST_DIR 文件夹不存在，请先安装 OpenList。"; return 1; }
  local DOWNLOAD_URL
  DOWNLOAD_URL=$(get_latest_url)
  if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${ERROR} 未能获取到最新 OpenList 安装包下载地址。"
    return 1
  fi
  pushd "$SCRIPT_DIR" > /dev/null || { echo -e "${ERROR} 无法切换到脚本目录。"; return 1; }
  echo -e "${INFO} 正在下载 ${YELLOW}$FILE_NAME${NC} ..."
  download_with_progress "$DOWNLOAD_URL" "$FILE_NAME" || { echo -e "${ERROR} 下载文件失败。"; popd > /dev/null; return 1; }
  echo -e "${INFO} 正在解压 ${YELLOW}$FILE_NAME${NC} ..."
  extract_file "$FILE_NAME" || { echo -e "${ERROR} 解压文件失败。"; popd > /dev/null; return 1; }
  rm -f "$DEST_DIR/openlist"
  mv -f openlist "$DEST_DIR/"
  chmod +x "$DEST_DIR/openlist"
  rm -f "$FILE_NAME"
  echo -e "${SUCCESS} OpenList 更新完成！"
  popd > /dev/null
  return 0
}

check_process() {
  pgrep -f "./openlist server" > /dev/null
}

check_aria2_process() {
  pgrep -f "$ARIA2_CMD --enable-rpc" > /dev/null
}

start_openlist() {
  ensure_tools
  [ ! -d "$DEST_DIR" ] && { echo -e "${ERROR} $DEST_DIR 文件夹不存在，请先安装 OpenList。"; return 1; }
  mkdir -p "$OPENLIST_LOGDIR"
  if check_process; then
    PIDS=$(pgrep -f "./openlist server")
    echo -e "${WARN} OpenList server 已运行，PID：$PIDS"
    read -p "是否终止现有进程？(y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      echo -e "${INFO} 正在终止 OpenList server 进程..."
      pkill -f "./openlist server"
      sleep 1
      check_process && { echo -e "${ERROR} 无法终止 OpenList server 进程。"; return 1; }
    else
      echo -e "${INFO} 取消启动新进程。"
      return 0
    fi
  fi
  echo -e "${INFO} 进入 $DEST_DIR 文件夹..."
  pushd "$DEST_DIR" > /dev/null || { echo -e "${ERROR} 进入 $DEST_DIR 失败。"; return 1; }
  [ ! -f "openlist" ] && { echo -e "${ERROR} 未找到 openlist 可执行文件。"; popd > /dev/null; return 1; }
  [ ! -x "openlist" ] && chmod +x openlist
  divider
  echo -e "${INFO} 启动 openlist server..."
  ./openlist server > "$OPENLIST_LOG" 2>&1 &
  OPENLIST_PID=$!
  sleep 3
  if ps -p "$OPENLIST_PID" > /dev/null 2>&1; then
    echo -e "${SUCCESS} OpenList server 已启动 (PID: $OPENLIST_PID)。"
  else
    echo -e "${ERROR} OpenList server 启动失败。"
    popd > /dev/null
    return 1
  fi
  if [ -f "$OPENLIST_LOG" ]; then
    PASSWORD=$(grep -oP '(?<=initial password is: )\S+' "$OPENLIST_LOG")
    if [ -n "$PASSWORD" ]; then
      echo -e "${SUCCESS} 检测到 OpenList 初始账户信息："
      echo -e "    用户名：${YELLOW}admin${NC}"
      echo -e "    密码：  ${YELLOW}$PASSWORD${NC}"
      echo -e "${INFO} 请在系统浏览器中访问：${YELLOW}http://localhost:5244${NC}"
    else
      echo -e "${WARN} 未在日志中找到初始密码，可能不是首次启动或请使用您设置的密码。"
      echo -e "${INFO} 若您已设置过账户密码，请直接访问：${YELLOW}http://localhost:5244${NC}"
    fi
  else
    echo -e "${ERROR} 未生成 openlist.log 日志文件。"
    echo -e "${INFO} 您可以尝试访问：${YELLOW}http://localhost:5244${NC}"
  fi
  echo -e "${INFO} 日志文件位于 ${YELLOW}$OPENLIST_LOG${NC}"
  divider
  popd > /dev/null
  return 0
}

stop_openlist() {
  if check_process; then
    PIDS=$(pgrep -f "./openlist server")
    echo -e "${INFO} 检测到 OpenList server 正在运行，PID：$PIDS"
    echo -e "${INFO} 正在终止 OpenList server..."
    pkill -f "./openlist server"
    sleep 1
    check_process && { echo -e "${ERROR} 无法终止 OpenList server 进程。"; return 1; }
    echo -e "${SUCCESS} OpenList server 已成功终止。"
  else
    echo -e "${WARN} OpenList server 未运行。"
  fi
  return 0
}

start_aria2() {
  ensure_tools
  mkdir -p "$ARIA2_DIR"
  if check_aria2_process; then
    PIDS=$(pgrep -f "$ARIA2_CMD --enable-rpc")
    echo -e "${WARN} aria2 已运行，PID：$PIDS"
    read -p "是否终止现有进程？(y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      echo -e "${INFO} 正在终止 aria2 进程..."
      pkill -f "$ARIA2_CMD --enable-rpc"
      sleep 1
      check_aria2_process && { echo -e "${ERROR} 无法终止 aria2 进程。"; return 1; }
    else
      echo -e "${INFO} 取消启动新进程。"
      return 0
    fi
  fi
  read -ep "请输入aria2 rpc密钥: " ARIA2_SECRET
  echo -e "${INFO} 启动 aria2c ..."
  nohup $ARIA2_CMD --enable-rpc --rpc-listen-all=true --rpc-secret="$ARIA2_SECRET" > "$ARIA2_LOG" 2>&1 &
  sleep 2
  local ARIA2_PID=$(pgrep -f "$ARIA2_CMD --enable-rpc" | head -n 1)
  if [ -n "$ARIA2_PID" ] && ps -p "$ARIA2_PID" > /dev/null 2>&1; then
    echo -e "${SUCCESS} aria2 已启动 (PID: $ARIA2_PID)。"
    echo -e "${INFO} 日志文件位置: ${YELLOW}$ARIA2_LOG${NC}"
    echo -e "${INFO} rpc 密钥: ${YELLOW}$ARIA2_SECRET${NC}"
  else
    echo -e "${ERROR} aria2 启动失败。"
    return 1
  fi
}

stop_aria2() {
  if check_aria2_process; then
    PIDS=$(pgrep -f "$ARIA2_CMD --enable-rpc")
    echo -e "${INFO} 检测到 aria2 正在运行，PID：$PIDS"
    echo -e "${INFO} 正在终止 aria2 ..."
    pkill -f "$ARIA2_CMD --enable-rpc"
    sleep 1
    check_aria2_process && { echo -e "${ERROR} 无法终止 aria2 进程。"; return 1; }
    echo -e "${SUCCESS} aria2 已成功终止。"
  else
    echo -e "${WARN} aria2 未运行。"
  fi
  return 0
}

aria2_status_line() {
  if check_aria2_process; then
    PIDS=$(pgrep -f "$ARIA2_CMD --enable-rpc")
    echo -e "${INFO} aria2 状态：${GREEN}运行中 (PID: $PIDS)${NC}"
  else
    echo -e "${INFO} aria2 状态：${RED}未运行${NC}"
  fi
}

view_openlist_log() {
  LOG_FILE="$OPENLIST_LOG"
  if [ ! -f "$LOG_FILE" ]; then
    echo -e "${ERROR} 未找到OpenList日志文件：$LOG_FILE"
    return 1
  fi
  echo -e "${INFO} 显示OpenList日志文件：${YELLOW}$LOG_FILE${NC}"
  cat "$LOG_FILE"
  echo -e "按回车键返回菜单..."
  read -r
}

view_aria2_log() {
  LOG_FILE="$ARIA2_LOG"
  if [ ! -f "$LOG_FILE" ]; then
    echo -e "${ERROR} 未找到aria2日志文件：$LOG_FILE"
    return 1
  fi
  echo -e "${INFO} 显示aria2日志文件：${YELLOW}$LOG_FILE${NC}"
  cat "$LOG_FILE"
  echo -e "按回车键返回菜单..."
  read -r
}

update_script() {
  ensure_tools
  TMP_FILE="oplist.sh.new"
  echo -e "${INFO} 正在下载最新管理脚本..."
  curl -L --progress-bar -o "$TMP_FILE" https://raw.githubusercontent.com/giturass/openlist_termux/refs/heads/main/oplist.sh
  if [ $? -eq 0 ] && [ -s "$TMP_FILE" ]; then
    chmod +x "$TMP_FILE"
    mv "$TMP_FILE" oplist.sh
    echo -e "${SUCCESS} 管理脚本已更新为最新版本。"
    echo -e "${INFO} 请用命令：${YELLOW}bash oplist.sh${NC} 重新运行。"
  else
    echo -e "${ERROR} 下载最新管理脚本失败，请检查网络或稍后再试。"
    rm -f "$TMP_FILE"
  fi
  echo -e "按回车键返回菜单..."
  read -r
}

show_menu() {
  clear
  divider
  echo -e "${GREEN}       OpenList 管理菜单${NC}"
  divider
  if check_process; then
    PIDS=$(pgrep -f "./openlist server")
    echo -e "${INFO} OpenList 状态：${GREEN}运行中 (PID: $PIDS)${NC}"
  else
    echo -e "${INFO} OpenList 状态：${RED}未运行${NC}"
  fi
  aria2_status_line
  divider
  echo -e "${YELLOW}1)${NC} 安装 OpenList 最新版"
  echo -e "${YELLOW}2)${NC} 更新 OpenList 到最新版"
  echo -e "${YELLOW}3)${NC} 启动 OpenList"
  echo -e "${YELLOW}4)${NC} 停止 OpenList"
  echo -e "${YELLOW}5)${NC} 启动 aria2"
  echo -e "${YELLOW}6)${NC} 停止 aria2"
  echo -e "${YELLOW}7)${NC} 查看OpenList启动日志"
  echo -e "${YELLOW}8)${NC} 查看aria2启动日志"
  echo -e "${YELLOW}9)${NC} 更新管理脚本"
  echo -e "${YELLOW}0)${NC} 退出"
  divider
}

while true; do
  show_menu
  read -ep "请输入选项 (0-9): " choice
  case $choice in
    1) install_openlist; echo -e "按回车键返回菜单..."; read -r ;;
    2) update_openlist; echo -e "按回车键返回菜单..."; read -r ;;
    3) start_openlist; echo -e "按回车键返回菜单..."; read -r ;;
    4) stop_openlist; echo -e "按回车键返回菜单..."; read -r ;;
    5) start_aria2; echo -e "按回车键返回菜单..."; read -r ;;
    6) stop_aria2; echo -e "按回车键返回菜单..."; read -r ;;
    7) view_openlist_log ;;
    8) view_aria2_log ;;
    9) update_script ;;
    0) echo -e "${INFO} 退出程序。"; exit 0 ;;
    *) echo -e "${ERROR} 无效选项，请输入 0-9。"; echo -e "按回车键返回菜单..."; read -r ;;
  esac
done
