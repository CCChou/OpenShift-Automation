#!/bin/bash

# nfs_csi
nfs_csi(){
    echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 ${CSI_MODULE}..."

    # 配置NFS
    NFS_SC_DIR="/nfs"    
    NFS_CIDR=$(hostname -I | awk '{print $1}' | awk -F. '{print $1"."$2".0.0/16"}')    

    mkdir -p $NFS_SC_DIR
    chmod 777 $NFS_SC_DIR
    echo "$NFS_SC_DIR $NFS_CIDR(rw,sync,no_root_squash,no_subtree_check,no_wdelay)" | tee /etc/exports

    dnf install nfs-utils -y
    systemctl restart nfs-server rpcbind
    systemctl enable --now nfs-server rpcbind nfs-mountd
 
    # 創建 nfs namespace
    echo -e "[$(date)] \e[32mINFO\e[0m：創建 ${STORAGE_NAMESPACE}..."
    oc create namespace "${STORAGE_NAMESPACE}" || echo " ${STORAGE_NAMESPACE} 已存在。"

    # 創建 ServiceAccount 和 RBAC 權限
    envsubst < ${YAML_DIR}/${CSI_MODULE}/rbac-csi-nfs.yaml |oc apply -f -

    oc adm policy add-scc-to-user privileged -z csi-nfs-controller-sa -n ${STORAGE_NAMESPACE}
    oc adm policy add-scc-to-user privileged -z csi-nfs-node-sa -n ${STORAGE_NAMESPACE}
    
    # 創建 csi driver
    envsubst < ${YAML_DIR}/${CSI_MODULE}/csi-nfs-driverinfo.yaml |oc apply -f -
    
    # 部署 NFS Controller
    if oc get deployment csi-nfs-controller -n "${STORAGE_NAMESPACE}" &> /dev/null; then
        echo -e "[$(date)] \e[32mINFO\e[0m：NFS Controller 已存在，跳過部署。"
    else
      envsubst < ${YAML_DIR}/${CSI_MODULE}/csi-nfs-controller.yaml |oc apply -f -
    fi

    # 部署 NFS Node
    if oc get daemontset csi-nfs-node -n "${STORAGE_NAMESPACE}" &> /dev/null; then
        echo -e "[$(date)] \e[32mINFO\e[0m：NFS Node Daemon 已存在，跳過部署。"
    else
      envsubst < ${YAML_DIR}/${CSI_MODULE}/csi-nfs-node.yaml |oc apply -f -
    fi

    # 創建 StorageClass
    envsubst < ${YAML_DIR}/${CSI_MODULE}/storageclass.yaml |oc apply -f -

    # 創建 SnapshotClass
    envsubst < ${YAML_DIR}/${CSI_MODULE}/snapshotclass.yaml |oc apply -f -

    # 設置預設 StorageClass
    oc patch storageclass ${STORAGE_CLASS_NAME} -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'

    echo -e "[$(date)] \e[32mINFO\e[0m：nfs_csi 執行完成"
}

# trident csi
trident(){
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 ${CSI_MODULE}..."

  TRIDENT_TAR_FILE="/root/install_source/trident-installer-25.02.1.tar.gz"
  TRIDENT_TARGET_DIR="/root/install_source/"

  # 檢查文件是否存在，存在便解 tar
  if [ -f "$TRIDENT_TAR_FILE" ]; then
    echo -e "[$(date)] \e[32mINFO\e[0m：檢查到文件存在，開始解 tar..."
    tar -zxvf "$TRIDENT_TAR_FILE" -C "$TRIDENT_TARGET_DIR"
    echo -e "[$(date)] \e[32mINFO\e[0m：解 tar 完成！"
  else
    echo -e "[$(date)] \e[31mERROR\e[0m：文件 $TRIDENT_TAR_FILE 不存在。"
    exit 1 
  fi

  # 創建 trident orchestrators crd
  envsubst < ${YAML_DIR}/${CSI_MODULE}/tridentorchestrators-crd.yaml |oc apply -f -

  # 創建 trident namespace
  echo -e "[$(date)] \e[32mINFO\e[0m：創建 ${STORAGE_NAMESPACE}..."
  envsubst < ${YAML_DIR}/${CSI_MODULE}/namespace.yaml |oc apply -f -

  # 創建部署 bundle
  if oc get deployment trident-operator -n "${STORAGE_NAMESPACE}" &> /dev/null; then
      echo -e "[$(date)] \e[32mINFO\e[0m：trident operator 已存在，跳過部署。"
  else
    envsubst < ${YAML_DIR}/${CSI_MODULE}/deploy-bundle.yaml |oc apply -f -
  fi
  
  # 創建 trident orchestrator
  if oc get tridentorchestrator trident -n "${STORAGE_NAMESPACE}" &> /dev/null; then
      echo -e "[$(date)] \e[32mINFO\e[0m：tridentorchestrator 已存在，跳過部署。"
  else
    envsubst < ${YAML_DIR}/${CSI_MODULE}/tridentorchestrator.yaml |oc apply -f -
  fi

  # 讓 tridentctl CLI 可以執行
  cp -raf /root/install_source/trident-installer/tridentctl /usr/bin
  chmod a+x /usr/bin/tridentctl

  # 創建 trident backend
  # TODO 缺檢查機制，目前先 sleep 硬解
  sleep 180s
  envsubst < ${YAML_DIR}/${CSI_MODULE}/backend.json |tridentctl create backend -n ${STORAGE_NAMESPACE} -f - 

  # 創建 StorageClass
  envsubst < ${YAML_DIR}/${CSI_MODULE}/storageclass.yaml |oc apply -f -
  
  # 創建 volumesnapshotclass
  oc apply -f ${YAML_DIR}/${CSI_MODULE}/volumesnapshotclass.yaml

  echo -e "[$(date)] \e[32mINFO\e[0m：trident 執行完成"
}
