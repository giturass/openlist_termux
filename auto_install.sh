#!/bin/bash

FILE_NAME="openlist-android-arm64.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$SCRIPT_DIR/Openlist"
DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/download/beta/openlist-android-arm64.tar.gz"

download_file() {
  echo "正在下载 $FILE_NAME..."
  curl -L -o "$FILE_NAME" "$DOWNLOAD_URL"
  if [ $? -ne 0 ]; then
    echo "错误：下载文件失败。"
    return 1
  fi
  return 0
}

extract_file() {
  echo "正在解压 $FILE_NAME..."
  tar -zxvf "$FILE_NAME"
  if [ $? -ne 0 ]; then
    echo "错误：解压文件失败。"
    return 1
  fi
  if [ ! -f "openlist" ]; then
    echo "错误：未找到 openlist 可执行文件。"
    return 1
  fi
  return 0
}

install_openlist() {
  pushd "$SCRIPT_DIR" > /dev/null || { echo "错误：无法切换到脚本目录。"; return 1; }
  download_file || { popd > /dev/null; return 1; }
  extract_file || { popd > /dev/null; return 1; }
  echo "创建 $DEST_DIR 文件夹..."
  mkdir -p "$DEST_DIR"
  if [ $? -ne 0 ]; then
    echo "错误：创建 $DEST_DIR 文件夹失败。"
    popd > /dev/null
    return 1
  fi
  echo "移动 openlist 到 $DEST_DIR 文件夹..."
  mv openlist "$DEST_DIR/"
  if [ $? -ne 0 ]; then
    echo "错误：移动 openlist 文件失败。"
    popd > /dev/null
    return 1
  fi
  echo "赋予 openlist 可执行权限..."
  chmod +x "$DEST_DIR/openlist"
  if [ $? -ne 0 ]; then
    echo "错误：设置可执行权限失败。"
    popd > /dev/null
    return 1
  fi
  echo "清理下载的压缩包..."
  rm -f "$FILE_NAME"
  echo "OpenList 安装完成！"
  popd > /dev/null
  return 0
}

update_openlist() {
  if [ ! -d "$DEST_DIR" ]; then
    echo "错误：$DEST_DIR 文件夹不存在，请先安装 OpenList。"
    return 1
  fi
  pushd "$SCRIPT_DIR" > /dev/null || { echo "错误：无法切换到脚本目录。"; return 1; }
  download_file || { popd > /dev/null; return 1; }
  extract_file || { popd > /dev/null; return 1; }
  echo "删除 $DEST_DIR 文件夹内的旧 openlist 文件..."
  rm -f "$DEST_DIR/openlist"
  if [ $? -ne 0 ]; then
    echo "错误：删除旧 openlist 文件失败。"
    popd > /dev/null
    return 1
  fi
  echo "移动新 openlist 到 $DEST_DIR 文件夹..."
  mv openlist "$DEST_DIR/"
  if [ $? -ne 0 ]; then
    echo "错误：移动新 openlist 文件失败。"
    popd > /dev/null
    return 1
  fi
  echo "赋予 openlist 可执行权限..."
  chmod +x "$DEST_DIR/openlist"
  if [ $? -ne 0 ]; then
    echo "错误：设置可执行权限失败。"
    popd > /dev/null
    return 1
  fi
  echo "清理下载的压缩包..."
  rm -f "$FILE_NAME"
  echo "OpenList 更新完成！"
  popd > /dev/null
  return 0
}

check_process() {
  if pgrep -f "./openlist server" > /dev/null; then
    return 0
  fi
  return 1
}

start_openlist() {
  if [ ! -d "$DEST_DIR" ]; then
    echo "错误：$DEST_DIR 文件夹不存在，请先安装 OpenList。"
    return 1
  fi
  if check_process; then
    PIDS=$(pgrep -f "./openlist server")
    echo "警告：OpenList server 已运行，PID：$PIDS"
    read -p "是否终止现有进程？(y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      echo "终止 OpenList server 进程..."
      pkill -f "./openlist server"
      sleep 1
      if check_process; then
        echo "错误：无法终止 OpenList server 进程。"
        return 1
      fi
    else
      echo "取消启动新进程。"
      return 0
    fi
  fi
  echo "进入 $DEST_DIR 文件夹..."
  pushd "$DEST_DIR" > /dev/null || { echo "错误：进入 $DEST_DIR 文件夹失败。"; return 1; }
  if [ ! -f "openlist" ]; then
    echo "错误：未找到 openlist 可执行文件。"
    popd > /dev/null
    return 1
  fi
  if [ ! -x "openlist" ]; then
    echo "赋予 openlist 可执行权限..."
    chmod +x openlist
    if [ $? -ne 0 ]; then
      echo "错误：设置可执行权限失败。"
      popd > /dev/null
      return 1
    fi
  fi
  echo "启动 openlist server..."
  ./openlist server > openlist.log 2>&1 &
  OPENLIST_PID=$!
  sleep 3
  if ps -p "$OPENLIST_PID" > /dev/null 2>&1; then
    echo "OpenList server 已启动（PID: $OPENLIST_PID）。"
  else
    echo "错误：OpenList server 启动失败。"
    popd > /dev/null
    return 1
  fi
  if [ -f "openlist.log" ]; then
    PASSWORD=$(grep -oP '(?<=initial password is: )\S+' openlist.log)
    if [ -n "$PASSWORD" ]; then
      echo "检测到 OpenList 初始密码：$PASSWORD"
    else
      echo "未在日志中找到初始密码，可能不是首次启动或请使用您设置的密码。"
    fi
  else
    echo "错误：未生成 openlist.log 日志文件。"
  fi
  echo "日志文件位于 $DEST_DIR/openlist.log，可查看详细信息。"
  popd > /dev/null
  return 0
}

stop_openlist() {
  if check_process; then
    PIDS=$(pgrep -f "./openlist server")
    echo "检测到 OpenList server 正在运行，PID：$PIDS"
    echo "正在终止 OpenList server..."
    pkill -f "./openlist server"
    sleep 1
    if check_process; then
      echo "错误：无法终止 OpenList server 进程。"
      return 1
    fi
    echo "OpenList server 已成功终止。"
  else
    echo "OpenList server 未运行。"
  fi
  return 0
}

show_menu() {
  clear
  echo "OpenList 管理菜单"
  echo "================="
  if check_process; then
    PIDS=$(pgrep -f "./openlist server")
    echo "OpenList 状态：运行中 (PID: $PIDS)"
  else
    echo "OpenList 状态：未运行"
  fi
  echo "================="
  echo "1) 安装 OpenList 最新版"
  echo "2) 更新 OpenList 到最新版"
  echo "3) 启动 OpenList"
  echo "4) 停止 OpenList"
  echo "5) 退出"
  echo "================="
  read -p "请输入选项 (1-5): " choice
  return $choice
}

while true; do
  show_menu
  choice=$?
  case $choice in
    1)
      install_openlist
      echo "按回车键返回菜单..."
      read -r
      ;;
    2)
      update_openlist
      echo "按回车键返回菜单..."
      read -r
      ;;
    3)
      start_openlist
      echo "按回车键返回菜单..."
      read -r
      ;;
    4)
      stop_openlist
      echo "按回车键返回菜单..."
      read -r
      ;;
    5)
      echo "退出程序。"
      exit 0
      ;;
    *)
      echo "错误：无效选项，请输入 1、2、3、4 或 5。"
      echo "按回车键返回菜单..."
      read -r
      ;;
  esac
done
