#!/bin/bash
# 在預設目錄(/root/install/ocp)建立md5檢查
# sh checkmd5_verify.sh create
# 在指定目錄建立md5檢查檔
# sh checkmd5_verify.sh create /some/other/path

# 在預設目錄(/root/install/ocp)檢查
# sh checkmd5_verify.sh check 
# 在指定目錄檢查
# sh checkmd5_verify.sh check /some/other/path


DEFAULT_DIR="/root/install/ocp"
TARGET_DIR="${2:-$DEFAULT_DIR}"
LOG_FILE="checkmd5_verify.log"

create() {
  if ! cd "$TARGET_DIR"; then
    echo -e "[$(date)] \e[31mERROR\e[0m：目錄不存在：$TARGET_DIR"
    exit 1
  fi

  echo -e "[$(date)] \e[32mINFO\e[0m：建立 .md5 檔案中..."
  for file in mirror*.tar; do
    md5sum "$file" > "${file}.md5"
    echo -e "[$(date)] \e[32mINFO\e[0m：已建立：${file}.md5"
  done
}

check() {
  if ! cd "$TARGET_DIR"; then
    echo -e "[$(date)] \e[31mERROR\e[0m：目錄不存在：$TARGET_DIR"
    exit 1
  fi

  echo -e "[$(date)] \e[32mINFO\e[0m：驗證 MD5 中..."
  > "$LOG_FILE"

  for file in mirror*.tar; do
    if ! md5sum -c "${file}.md5" >> "$LOG_FILE" 2>&1; then
      echo -e "[$(date)] \e[31mERROR\e[0m：驗證失敗：$file，詳見 $LOG_FILE"
      exit 1
    else
      echo -e "[$(date)] \e[32mINFO\e[0m：驗證通過：$file"
    fi
  done

  echo -e "[$(date)] \e[32mINFO\e[0m：所有檔案驗證完成"
}

# 主程式入口
case "$1" in
  create)
    create
    ;;
  check)
    check
    ;;
  *)
    echo "用法: $0 {create|check} [目錄]"
    exit 1
    ;;
esac

