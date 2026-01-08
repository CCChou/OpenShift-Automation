#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_file="$SCRIPT_DIR/post_install.conf"


# 檢查文件是否存在
[[ ! -f "$config_file" ]] && { echo -e "[$(date)] \e[31mERROR\e[0m：配置文件不存在"; exit 1; }

# 逐行讀取並解析
while IFS= read -r line || [[ -n "$line" ]]; do
  # 去除註解和空白
  line_clean=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  # 跳過空行
  [[ -z "$line_clean" ]] && continue
  
  # 分割鍵值並賦值
  key=$(echo "$line_clean" | cut -d '=' -f 1 | xargs)
  value=$(echo "$line_clean" | cut -d '=' -f 2- | xargs)
  # 定義變量
  declare -- "$key=$value"
done < "$config_file"

export KUBECONFIG="/root/ocp4/auth/kubeconfig"
export YAML_DIR="/root/OpenShift-Automation/yaml"

echo -e "[$(date)] \e[32mINFO\e[0m：post_install.conf 配置檔確認完畢，開始執行 post_install.sh"

# 主程式
main(){
  # 先不破壞既有的做法
  if [ "$1" = "" ]; then
    approve_csr
    mirror_source_config
    ocp_authentication
    csi_installation
    infra_node_setup
    create_gitea
  fi

  if [ "$1" = "wait-complete" ]; then
    approve_csr
    mirror_source_config
    ocp_authentication
  elif [ "$1" = "install-csi" ]; then
    csi_installation
  elif [ "$1" = "post-configure" ]; then
    infra_node_setup
    create_gitea
  fi
}

# 驗證通過 CSR
approve_csr(){
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 approve_csr..."

  TARGET_READY_COUNT=${TOTAL_NODE_NUMBER}
  CHECK_INTERVAL=$((5 * 60)) # 每 5 分鐘檢查一次
  MAX_WAIT_SECONDS=$((40 * 60)) # 最長等待 40 分鐘
  START_TIME=$(date +%s)

  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_SECONDS=$((CURRENT_TIME - START_TIME))
    
    if [ "$ELAPSED_SECONDS" -ge "$MAX_WAIT_SECONDS" ]; then
        echo -e "[$(date)] \e[31mERROR\e[0m：等待超時（${MAX_WAIT_SECONDS}秒）"
        exit 1
    fi
    
    CURRENT_READY=$(oc get nodes -o json | \
        jq '[.items[] | select(.status.conditions[] | select(.reason == "KubeletReady" and .status == "True"))] | length')
    
    if [ "$CURRENT_READY" -eq "$TARGET_READY_COUNT" ]; then
        echo -e "$(date): \e[32mINFO\e[0m：所有節點就緒"
        break
    fi

    # 執行 CSR 核准
    oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' \
            | xargs -r oc adm certificate approve
    
    sleep $CHECK_INTERVAL
  done

  # 檢查 cluster operator
  # TODO 加上超時設定與 echo 訊息
  while true; do
    CO_READY=$(oc get co | awk 'BEGIN{ok=1} NR>1{if(!($3=="True"&&$4=="False"&&$5=="False")) ok=0} END{if(ok) print "OK"}')
    if [ "OK" == $CO_READY ]; then
      echo -e "$(date): \e[32mINFO\e[0m：所有 Cluster Operator 就緒"
      break
    fi

    sleep $CHECK_INTERVAL
  done

  echo -e "[$(date)] \e[32mINFO\e[0m：approve_csr 執行完成"
}

# 配置 mirror 來源
mirror_source_config(){
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 mirror_source_config..."

  # 關閉預設 catalog source
  oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'

  # 查找 redhat operator catalogsource
  oc_mirror_workspace="/root/mirror-workspace"
  redhat_operator_cs="$(ls -1 $oc_mirror_workspace/cluster-resources/cs-redhat-operator-index-v*.yaml | head -n 1)"
  idms="$oc_mirror_workspace/cluster-resources/idms-oc-mirror.yaml"
  itms="$oc_mirror_workspace/cluster-resources/itms-oc-mirror.yaml"

  # 檢查是否找到文件
  if [ ! -f "$redhat_operator_cs" ] || [ ! -f "$idms" ] || [ ! -f "$itms" ]; then
    echo -e "[$(date)] \e[31mERROR\e[0m：未找到 catalogSource-cs-redhat-operator-index.yaml / idms-oc-mirror.yaml / itms-oc-mirror.yaml  文件"
    exit 1
  fi

  # 找到文件後將 name 替換成 redhat-operators
  #sed -i.bak '/^ *name: /s/cs-redhat-operator-index/redhat-operators/' $redhat_operator_cs
  sed -i.bak -E \
  '/^[[:space:]]*name:[[:space:]]*cs-redhat-operator-index/s/cs-redhat-operator-index[^[:space:]]*/redhat-operators/' \
  "$redhat_operator_cs"

  # 將 CatalogSource apply 
  oc apply -f $redhat_operator_cs
  oc apply -f $idms
  oc apply -f $itms

  echo -e "[$(date)] \e[32mINFO\e[0m：mirror_source_config 執行完成"
}

# 建立 OCP 的認證機制
ocp_authentication(){
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 ocp_authentication..."

  # 建立一個名為 htpass-secret 的 Secret 來儲存 htpasswd 檔案，帳密為ocpadmin P@ssw0rdocp
  oc apply -f ${YAML_DIR}/authentication/secret_htpasswd.yaml
 
  # 將資源套用至預設 OAuth 配置以新增identity provider。
  oc apply -f ${YAML_DIR}/authentication/oauth.yaml

  # 賦予 ocpadmin 帳號 cluster-admin role
  oc adm policy add-cluster-role-to-user cluster-admin ocpadmin
  
  oc get secret htpass-secret -n openshift-config > /dev/null 2>&1
  htpass_secret_status=$?
  oc get secret kubeadmin -n kube-system > /dev/null 2>&1
  kubeadmin_secret_status=$?

  # 檢查 htpasswd Secret 和 kubeadmin secret 是否存在
  if [ $htpass_secret_status -eq 0 ] && [ $kubeadmin_secret_status -eq 0 ]; then
    echo -e "[$(date)] \e[32mINFO\e[0m：Secret [htpass-secret] 已存在，刪除 kubeadmin。"

    # 刪除 kubeadmin 
    oc delete secret kubeadmin -n kube-system

  # 檢查 htpasswd Secret 是否存在
  elif [ $htpass_secret_status -ne 0 ]; then
    echo -e "[$(date)] \e[31mERROR\e[0m：Secret [htpass-secret] 不存在，請確認是否建立 Secert。"
    exit 1
  fi

  echo -e "[$(date)] \e[32mINFO\e[0m：ocp_authentication 執行完成"
}

# 安裝 CSI 及創建預設 storageclass
csi_installation(){
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 csi_installation..."

  export OCP_DOMAIN=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")
  export OCP_VERSION=420
    
  source /root/OpenShift-Automation/scripts/install_csi.sh

  # 主程式入口
  case "$CSI_MODULE" in
    nfs-csi)
      export STORAGE_CLASS_NAME=${NFS_STORAGE_CLASS_NAME}
      export STORAGE_NAMESPACE=${NFS_NAMESPACE}
      nfs_csi
      ;;
    trident)
      export STORAGE_CLASS_NAME=${TRIDENT_STORAGE_CLASS_NAME}
      export STORAGE_NAMESPACE=${TRIDENT_NAMESPACE}
      export BACKEND_TYPE=${BACKEND_TYPE}
      export BACKEND_NAME=${BACKEND_NAME}
      export STORAGE_DRIVER_NAME=${STORAGE_DRIVER_NAME}
      export MANAGEMENT_LIF=${MANAGEMENT_LIF}
      export DATA_LIF=${DATA_LIF}
      export SVM=${SVM}
      export ONTAP_USERNAME=${ONTAP_USERNAME}
      export ONTAP_PASSWORD=${ONTAP_PASSWORD}
      trident
      ;;
    *)
      echo -e "[$(date)] \e[32mINFO\e[0m：用法: $0 {nfs-nsi|trident} [目錄]"
      exit 1
      ;;
  esac
  
  wait

  # 檢查 StorageClass 是否創建成功
  if oc get storageclass ${STORAGE_CLASS_NAME} &> /dev/null; then
    echo -e "[$(date)] \e[32mINFO\e[0m： ${STORAGE_CLASS_NAME} 配置完成！CSI 及預設 storageclass 安裝完成！"
  else
    echo -e "[$(date)] \e[31mERROR\e[0m：CSI 及預設 StorageClass 創建失敗！"
    exit 1
  fi

  echo -e "[$(date)] \e[32mINFO\e[0m：csi_installation 執行完成"
}

# 配置 infra 節點
infra_node_setup(){
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 infra_node_setup..."

  if [ "${INSTALL_MODE}" == "standard" ]; then
    # standard mode 時執行以下動作
    echo -e "[$(date)] \e[32mINFO\e[0m：配置 standard 模式"

    # 設定infra node mcp
    oc apply -f ${YAML_DIR}/infra/mcp_infra.yaml

    # 將 infra node role 改為 infra
    for i in {01..03}; do
      oc label nodes infra$i.${OCP_DOMAIN} node-role.kubernetes.io/infra='';
      oc label nodes infra$i.${OCP_DOMAIN} node-role.kubernetes.io/worker-;
      oc adm taint node infra$i.${OCP_DOMAIN} \
      node-role.kubernetes.io/infra:NoSchedule \
      node-role.kubernetes.io/infra:NoExecute;
    done

    # 設定 Ingress pod to infra node
    oc patch ingresscontroller/default -n openshift-ingress-operator --type=merge -p '{"spec":{"replicas":3,"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}},"tolerations": [{"key": "node-role.kubernetes.io/infra","operator": "Exists"}]}}}'

    # Moving monitoring components to infra node 並設定 PV
    oc apply -f ${YAML_DIR}/infra/cm_cluster-monitoring-config-${INSTALL_MODE}.yaml

  elif [ "${INSTALL_MODE}" == "compact" ]; then
    # compact mode 時執行以下動作
    echo -e "[$(date)] \e[32mINFO\e[0m：配置 compact 模式"

    # monitoring components 設定 PV
    oc apply -f ${YAML_DIR}/infra/cm_cluster-monitoring-config-${INSTALL_MODE}.yaml
  else
    echo -e "[$(date)] \e[31mERROR\e[0m：模式配置錯誤"
    exit 1
  fi

  echo -e "[$(date)] \e[32mINFO\e[0m：infra_node_setup 執行完成"
}

# 創建 gitea server
create_gitea(){ 
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 create_gitea..."

  export GITEA_VERSION=${GITEA_VERSION}

  # 檢查 gitea pod 是否存在
  GITEA_STATUS=$(oc get pod -l app=gitea -n gitea -ojsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)

  if [ "${GITEA_STATUS}x" == "truex" ]; then
    echo -e "[$(date)] \e[32mINFO\e[0m：GITEA 已建立，請執行帳號登錄"
    exit 1
  fi

  oc get sa gitea-sa -n gitea > /dev/null 2>&1
  gitea_sa_status=$?

  # 建立 gitea 權限
  if [ $gitea_sa_status -eq 0 ]; then
    echo -e "[$(date)] \e[32mINFO\e[0m：ServiceAccount [gitea-sa] 已存在"
  else
    envsubst < ${YAML_DIR}/gitea/ns_gitea.yaml |oc apply -f -
    oc create sa gitea-sa -n gitea
    oc adm policy add-scc-to-user anyuid -z gitea-sa -n gitea
  fi
  
  # 配置鏡像參數
  envsubst < ${YAML_DIR}/gitea/create-gitea.yaml |oc apply -f -
  envsubst < ${YAML_DIR}/gitea/postgresql.yaml |oc apply -f -

  echo -e "[$(date)] \e[32mINFO\e[0m：create_gitea 執行完成"
  echo -e "[$(date)] \e[32mINFO\e[0m：post_install 腳本執行完成，GITEA 已建立，請執行帳號登錄"
}

main $1
