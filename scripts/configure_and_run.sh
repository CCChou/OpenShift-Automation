#!/bin/bash

# 清除參數的環境變數
unset $1


# 設定參數（可以在執行腳本時傳入）
export RHEL_MINOR_VERSION="${1:-9.6}"
export TARBALL_PATH="/root/install_source/ansible-navigator-rpm-${RHEL_MINOR_VERSION}.tar"
export TAR_DEST_PATH="/root/install_source/ansible-navigator-rpm-${RHEL_MINOR_VERSION}"
export EE_IMAGE_TAR="/root/install_source/eeimage-v1.tar"
export EE_IMAGE_NAME="quay.io/rhtw/ee-bas-auto:v1.0"

# 確認參數
echo -e "[$(date)] \e[32mINFO\e[0m： TARBALL_PATH   = $TARBALL_PATH"
echo -e "[$(date)] \e[32mINFO\e[0m： TAR_DEST_PATH  = $TAR_DEST_PATH"
echo -e "[$(date)] \e[32mINFO\e[0m： EE_IMAGE_TAR   = $EE_IMAGE_TAR"
echo -e "[$(date)] \e[32mINFO\e[0m： EE_IMAGE_NAME  = $EE_IMAGE_NAME"

# 解開所有準備好的 tar 包
mkdir -p ${TAR_DEST_PATH}
tar xvf ${TARBALL_PATH} -C ${TAR_DEST_PATH} --strip-components=1

# 安裝所有 rpm 包
yum localinstall -y ${TAR_DEST_PATH}/* --allowerasing --skip-broken

# 於 bastion 產生 ssh-key，並設定免密登入
if [ ! -f ~/.ssh/id_rsa ]; then
  echo -e "[$(date)] \e[32mINFO\e[0m：尚未存在 SSH 金鑰，開始產生..."
  ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <<< y
else
  echo -e "[$(date)] \e[32mINFO\e[0m：已存在 SSH 金鑰，跳過產生"
fi

# 確保 id_rsa.pub 加入 authorized_keys 中
pub_key=$(cat ~/.ssh/id_rsa.pub)
if ! grep -qF "$pub_key" ~/.ssh/authorized_keys 2>/dev/null; then
  echo "$pub_key" >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo -e "[$(date)] \e[32mINFO\e[0m：已將公鑰加入 authorized_keys"
else
  echo -e "[$(date)] \e[32mINFO\e[0m：公鑰已存在於 authorized_keys，跳過"
fi


# 從 tar 檔中載入容器映像檔到 Podman 的本地鏡像庫
podman load -i ${EE_IMAGE_TAR}

# 使用 ansible 運行自動化設定配置腳本
ansible-navigator run --eei ${EE_IMAGE_NAME} --pp missing -i /root/OpenShift-Automation/roles/inventory -m stdout /root/OpenShift-Automation/roles/install.yml

echo -e "[$(date)] \e[32mINFO\e[0m： configure_and_run 執行完成"