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
DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/download/beta/openlist-android-arm64.tar.gz"

divider() { echo -e "${YELLOW}------------------------------------------------------------${NC}"; }

download_file() {
  echo -e "${INFO} 正在下载 ${YELLOW}$FILE_NAME${NC} ..."
  curl -fsSL -o "$FILE_NAME" "$DOWNLOAD_URL"
  [ $? -ne 0 ] && { echo -e "${ERROR} 下载文件失败。"; return 1; }
  return 0
}

extract_file() {
  echo -e "${INFO} 正在解压 ${YELLOW}$FILE_NAME${NC} ..."
  tar -zxf "$FILE_NAME"
  [ $? -ne 0 ] && { echo -e "${ERROR} 解压文件失败。"; return 1; }
  [ ! -f "openlist" ] && { echo -e "${ERROR} 未找到 openlist 可执行文件。"; return 1; }
  return 0
}

install_openlist() {
  pushd "$SCRIPT_DIR" > /dev/null || { echo -e "${ERROR} 无法切换到脚本目录。"; return 1; }
  download_file || { popd > /dev/null; return 1; }
  extract_file || { popd > /dev/null; return 1; }
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
  [ ! -d "$DEST_DIR" ] && { echo -e "${ERROR} $DEST_DIR 文件夹不存在，请先安装 OpenList。"; return 1; }
  pushd "$SCRIPT_DIR" > /dev/null || { echo -e "${ERROR} 无法切换到脚本目录。"; return 1; }
  download_file || { popd > /dev/null; return 1; }
  extract_file || { popd > /dev/null; return 1; }
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

start_openlist() {
  [ ! -d "$DEST_DIR" ] && { echo -e "${ERROR} $DEST_DIR 文件夹不存在，请先安装 OpenList。"; return 1; }
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
  ./openlist server > openlist.log 2>&1 &
  OPENLIST_PID=$!
  sleep 3
  if ps -p "$OPENLIST_PID" > /dev/null 2>&1; then
    echo -e "${SUCCESS} OpenList server 已启动 (PID: $OPENLIST_PID)。"
  else
    echo -e "${ERROR} OpenList server 启动失败。"
    popd > /dev/null
    return 1
  fi
  if [ -f "openlist.log" ]; then
    PASSWORD=$(grep -oP '(?<=initial password is: )\S+' openlist.log)
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
  echo -e "${INFO} 日志文件位于 ${YELLOW}$DEST_DIR/openlist.log${NC}"
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

view_log() {
  LOG_FILE="$DEST_DIR/openlist.log"
  if [ ! -f "$LOG_FILE" ]; then
    echo -e "${ERROR} 未找到日志文件：$LOG_FILE"
    return 1
  fi
  echo -e "${INFO} 显示日志文件：${YELLOW}$LOG_FILE${NC}"
  cat "$LOG_FILE"
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
  divider
  echo -e "${YELLOW}1)${NC} 安装 OpenList 最新版"
  echo -e "${YELLOW}2)${NC} 更新 OpenList 到最新版"
  echo -e "${YELLOW}3)${NC} 启动 OpenList"
  echo -e "${YELLOW}4)${NC} 停止 OpenList"
  echo -e "${YELLOW}5)${NC} 查看日志"
  echo -e "${YELLOW}6)${NC} 退出"
  divider
}

while true; do
  show_menu
  read -ep "请输入选项 (1-6): " choice
  case $choice in
    1) install_openlist; echo -e "按回车键返回菜单..."; read -r ;;
    2) update_openlist; echo -e "按回车键返回菜单..."; read -r ;;
    3) start_openlist; echo -e "按回车键返回菜单..."; read -r ;;
    4) stop_openlist; echo -e "按回车键返回菜单..."; read -r ;;
    5) view_log ;;
    6) echo -e "${INFO} 退出程序。"; exit 0 ;;
    *) echo -e "${ERROR} 无效选项，请输入 1-6。"; echo -e "按回车键返回菜单..."; read -r ;;
  esac
done
