# OpenShift Automation

# WORK IN PROGRESS (版號 v0.x 不保證離線環境成功)

在符合最多數化場景下執行 OpenShift 的 Day1 跟 Day2 安裝配置自動化

| 版號 | 發布日期 | 異動內容 |
| :----: | :----: | :---- |
| v0.1 | 2025/03/28 | 首次更新 |
| v1.0 | 2025/06/17 | 4.18 Release |


## Related Projects
- [Ansible Role for OpenShift Day1 Setup](https://github.com/CCChou/ocp_bastion_installer)
- [OpenShift Environment as a Service](https://github.com/CCChou/OpenShift-EaaS-Practice)


## 安裝流程

### 事前準備流程

在進入客戶環境前的準備事項

0. 本機環境準備一台可對外連線的 RHEL 主機
   - 準備好 GitHub 帳號(Optional)
   - 主機 /etc/host 中設定解析 Red Hat registry
   - 檢查 /etc/yum.repos.d/ 內使用預設 RHEL repo
   - 在根目錄下需要有足夠的空間(建議200GB)

1. 註冊目前使用的本地機器
   ```bash
   subscription-manager register
   ```
   ```bash
   Username: ['你的 Red Hat 帳戶']
   Password: ['你的 Red Hat 帳戶密碼']
   ```

2. 安裝 git 並使用 git clone 將你自動化相關的 git repo 拉取下來
   - 安裝 git repo
     ```bash
     dnf install git -y
     ```

   - 拉取自動化 git repo
     * [OpenShift-Automation Repo](https://github.com/CCChou/OpenShift-Automation.git)
     
     ```bash
     cd /root
     ```
     ```bash
     git clone https://github.com/CCChou/OpenShift-Automation.git --branch <branchname>
     ```

3. 下載 pull-secret ，取名 pull-secret 並放到 /root 目錄下
   - 到 [Red Hat Hybrid Cloud Console](https://console.redhat.com/openshift/downloads) 下載 pull secret
     ![dowdload path](https://github.com/CCChou/OpenShift-Automation/blob/main/images/download_pullsecret.png)

4. 配置 prep_script.conf 內參數  (調整 /root/OpenShift-Automation/scripts/prep_script.conf 內的配置)
   - 使用 [Red Hat OpenShift Container Platform Update Graph](https://access.redhat.com/labs/ocpupgradegraph/update_path/) 查詢 OCP channel 及 version

   * 指令工具及系統檔案清單(以 4.18 stable 的 amd64 架構為範例):
     - 以下三個在對應 OpenShift 版號資料夾下:
       - [openshift-client](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/)
         ![openshift-client](https://github.com/CCChou/OpenShift-Automation/blob/main/images/oc-client.png)
       - [openshift-install](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/)
         ![openshift-install](https://github.com/CCChou/OpenShift-Automation/blob/main/images/oc-install.png)
       - [oc mirror plugin](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/)
         ![oc-mirror](https://github.com/CCChou/OpenShift-Automation/blob/main/images/oc-mirror.png)
       > 請注意，此三者需要為相同版號，且需要留意處理器架構是否與您的處理器相同。
     - [Butane config transpiler CLI](https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/)
       ![butane cli](https://github.com/CCChou/OpenShift-Automation/blob/main/images/butane.png)
     - [helm v3](https://mirror.openshift.com/pub/openshift-v4/clients/helm/)
       ![helm cli](https://github.com/CCChou/OpenShift-Automation/blob/main/images/helm-latest.png)
       > helm v3 請使用 latest 版本。
     - [mirror-registry](https://mirror.openshift.com/pub/openshift-v4/clients/mirror-registry/)
       ![mirror-registry](https://github.com/CCChou/OpenShift-Automation/blob/main/images/mirror-registry.png)
       > mirror registry v1 請使用最新版本。
     - [RHEL 開機用光碟 (REHL OS)](https://access.redhat.com/downloads/content/rhel)
     - [CoreOS 開機用光碟(rhcos)](https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/)

   ``` bash
   # prep_script.conf

   # GIT 目錄路徑
   OCP_INSTALLER_DIR=/root/OpenShift-Automation/roles/ocp_bastion_installer

   # Ansible EE 鏡像配置
   EE_IMAGE_NAME=eeimage

   # AAP 資訊
   AAP_REPO=ansible-automation-platform-2.5-for-rhel-9-x86_64-rpms
   AAP_DIR=/root/rpm
   RHEL_MINOR_VERSION=9.4

   # 版本資訊
   OCP_RELEASE=4.18.8
   RHEL_VERSION=rhel9
   ARCHITECTURE=amd64
   HELM_VERSION=3.15.4
   MIRROR_REGISTRY_VERSION=1.3.11

   # CSI 資訊
   CSI_TYPE=nfs-csi # nfs-csi | trident
   TRIDENT_INSTALLER= # trident installer 版本

   # 安裝環境資訊
   INSTALL_MODE=compact
   CLUSTER_DOMAIN=
   BASE_DOMAIN=
   BASTION_IP=
   BOOTSTRAP_IP=
   MASTER01_IP=
   MASTER02_IP=
   MASTER03_IP=
   INFRA01_IP=
   INFRA02_IP=
   INFRA03_IP=
   WORKER01_IP=
   WORKER02_IP=
   WORKER03_IP=
   REGISTRY_PASSWORD=P@ssw0rd
   ```
   
5. 執行 prep_script.sh
   ```bash
   sh /root/OpenShift-Automation/scripts/prep_script.sh
   ```
   
6. 使用 oc-mirror 指令將所需的鏡像拉取到本機
   * 使用 [Red Hat OpenShift Container Platform Operator Update Information Checker](https://access.redhat.com/labs/ocpouic/?upgrade_path=4.16%20to%204.18) 查詢 operator channel 及 version

   1. 取得常用 Operator 之資訊
      1. 取得目標版本的可用目錄
         ```bash
         # version 請選擇要安裝的 OpenShift 版本
         oc-mirror list operators --catalogs --version=4.XX
         ```
         以 4.18 為範例:
         ```bash
         oc-mirror list operators --catalogs --version=4.18
         ```
         輸出結果如下:
         ```bash
         Available OpenShift OperatorHub catalogs:
         OpenShift 4.18:
         registry.redhat.io/redhat/redhat-operator-index:v4.18
         registry.redhat.io/redhat/certified-operator-index:v4.18
         registry.redhat.io/redhat/community-operator-index:v4.18
         registry.redhat.io/redhat/redhat-marketplace-index:v4.18
         ```
      2. 在選定的目錄中尋找可用的 operator 資訊
         ```bash
         # image tag 請選擇要安裝的 OpenShift 版本
         oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.XX > package. out
         ```
         以 redhat-operator-index:4.18 為範例:
         ```bash
         oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.18 > package. out
         ```
         package. out 內容如下:
         ```bash
         NAME                                          DISPLAY NAME  DEFAULT CHANNEL
         ···
         cluster-logging                                             stable-6.2
         cluster-observability-operator                              stable
         ···
         ```
      3. 尋找所選 operator 的 channel 版本
         ```bash
         oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.XX --package=['operator 名稱']
         ```
         以 cluster-logging operator 為範例:
         ```bash
         oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.18 --package=cluster-logging
         ```
         輸出結果如下:
         ```bash
         NAME             DISPLAY NAME  DEFAULT CHANNEL
         cluster-logging                stable-6.2

         PACKAGE          CHANNEL     HEAD
         cluster-logging  stable-6.1  cluster-logging.v6.1.5
         cluster-logging  stable-6.2  cluster-logging.v6.2.1
         ```
      4. 找指定的頻道內的 package 版本
         ```bash
         oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.XX --package=['operator 名稱'] --channel=['operator 頻道']
         ```
         以 cluster-logging operator 為範例:
         ```bash
         oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.18 --package=cluster-logging --channel=stable-6.2
         ```
         輸出結果如下:
         ```bash
         VERSIONS
         6.2.0
         6.2.1
         ```
   2. 修改 imageSetConfiguration yaml 配置檔
       ```yaml
       apiVersion: mirror.openshift.io/v1alpha2
       kind: ImageSetConfiguration
       archiveSize: 4
       storageConfig:                                                      
         local:
           path: /root/install/ocp418/metadata
       mirror:
         platform:
           channels:
           - name: stable-4.18
             minVersion: 4.18.6
             maxVersion: 4.16.8
           graph: true
         operators:
         - catalog: registry.redhat.io/redhat/redhat-operator-index:v4.18
           packages:
           - name: cluster-logging
             channels:
             - name: stable-6.2
               minVersion: 6.2.1
               maxVersion: 6.2.1
           - name: loki-operator 
             channels:
             - name: stable-6.2
               minVersion: 6.2.1
               maxVersion: 6.2.1
         additionalImages:
         - name: registry.redhat.io/rhel8/rhel-guest-image:latest
         - name: registry.redhat.io/rhel9/rhel-guest-image:latest
       ```
       > 完整請參考 ( yaml > imageset-config.yaml)，請注意頻道和鏡像標籤
   3. 將鏡像從特定的 ImageSetConfiguration 中同步到磁碟
      - 執行 oc mirror 指令將指定 ImageSetConfiguration 中的鏡像同步到磁碟上
        ```bash
        cd /root/install/ocp418

        oc-mirror --config=./imageset-config.yaml file://.
        ```
      - 驗證是否已建立鏡像 .tar 檔案
        ```bash
        ls

        mirror_seq1_000000.tar
        mirror_seq1_000001.tar
        ···
        ```
   * 鏡像清單:
     - [openshift images]:
       - registry.redhat.io/ubi8/ubi:latest
       - registry.redhat.io/ubi9/ubi:latest
       - registry.redhat.io/rhel8/rhel-guest-image:latest
       - registry.redhat.io/rhel9/rhel-guest-image:latest
     - [operator images]: 
       - Virtualization
         - kubevirt-hyperconverged
         - mtv-operator
         - kubernetes-nmstate-operator
         - netobserv-operator
         - cluster-observability-operator
         - cluster-logging
         - loki-operator
         - tempo-product
         - opentelemetry-product
       - Storage
         - local-storage-operator
       - Day 2 Ops
         - node-healthcheck-operator
         - node-maintenance-operator
         - self-node-remediation
         - cincinnati-operator
         - openshift-gitops-operator
         - advanced-cluster-management
         - multicluster-engine
     - [additional images]: 
       - quay.io/stevewu/net-tools:latest
       - quay.io/containerdisks/fedora:latest
       - quay.io/containerdisks/centos:7-2009
       - quay.io/containerdisks/centos-stream:8
       - quay.io/containerdisks/centos-stream:9
       - quay.io/rhtw/postgres:17.5
       - quay.io/rhtw/gitea:1.21.7
       - quay.io/minio/minio:latest
       - quay.io/rhtw/tools
       - quay.io/rhtw/gitops-envsub

   4. 建立鏡像檔的md5檢查檔
      - 建立md5檢查檔
        ```bash
        sh /root/OpenShift-Automation/scripts/checkmd5_verify.sh create
        ```
      - 驗證是否已建立md5檢查檔
        ```bash
        ls

        mirror_seq1_000000.tar
        mirror_seq1_000000.tar.md5
        mirror_seq1_000001.tar
        mirror_seq1_000001.tar.md5
        ···
        ```

7. 將所有準備好的資源都 tar 起來準備放入客戶離線環境
   - 將 OpenShift Automation 目錄打包成 tar 檔
     ```bash
     tar czvf /root/openshift-automation.tar.gz -C /root OpenShift-Automation install_source OpenShift-EaaS-Practice
     ```

    * checkt list (不在openshift-automation.tar.gz內):
      - [x] mirror_seq
      - [x] qcow2
      - [x] vddk image 
      - [x] ISO
        - RHEL OS
        - rhcos

    * tar checkt list (tar包清單):
      - [x] ansible-navigator
      - [x] ee.tar
      - [x] git (調整配置後)
        - OpenShift-EaaS-Practice
        - ocp_bastion_installer
        - scripts
      - [x] image
        - csi images (如nfs、csm、trident)
      - [x] CLI tools
        - OpenShift command-line interface (oc)
        - Helm 3
        - Butane config transpiler CLI
      - [x] OpenShift installation
        - OpenShift for x86_64 Installer
      - [x] OpenShift disconnected installation tools
        - mirror registry for Red Hat OpenShift (mirror-registry)
        - OpenShift Client (oc) mirror plugin (oc-mirror)

8. (optional)若需要自行研究更新維護，可將自動化相關 github repo fork 到自己的 repo 中
   - 連線至 [OpenShift-Automation Repo](https://github.com/CCChou/OCP-Automation.git)，並點選 fork
   ![Fork01](https://github.com/CCChou/OpenShift-Automation/blob/main/images/fork01.png?raw=true)

   - 確認名稱沒有衝突後點選 Create fork
   ![Fork02](https://github.com/CCChou/OpenShift-Automation/blob/main/images/fork02.png?raw=true)

   - 成功 Fork 後可看到以下畫面，左上為目前 fork 出來的 repo 名稱以及關聯的源頭，右側 Code 點擊後則可以取得此 repo 後續用於 clone 的連結
   ![Fork03](https://github.com/CCChou/OpenShift-Automation/blob/main/images/fork03.png?raw=true)

### 離線安裝流程

0. 客戶環境準備一台離線環境的 Bastion RHEL 主機
   - 檢查 /etc/yum.repos.d/ 內不應有無效的 Repo
   - 在根目錄下需要有足夠的空間(建議600GB)
   - 請掛載對應 RHEL 版本的 ISO 檔案至光碟機

1. 將光碟機掛到檔案系統上及設定 YUM Repo
   ```bash
   mount /dev/sr0 /mnt
   
   vim /etc/yum.repos.d/local.repo
   
   [BaseOS]
   name = BaseOS
   baseurl = file:///mnt/BaseOS
   gpgcheck = 0
   enabled = 1
   
   [AppStream]
   name = AppStream
   baseurl = file:///mnt/AppStream
   gpgcheck = 0
   enabled = 1
   ```

2. 安裝 KVM 建立一個 RHEL VM (Optional)
   1. 請確定已於本地 OS 下載欲安裝的虛擬機之 ISO 檔
   2. 按照下方指令下載所需要之 RPM 套件
      ```bash
      dnf install libvirt qemu-kvm virt-install virt-manager virt-viewer -y 
      ```
   3. 啟動 libvirtd 服務
      ```bash 
      systemctl enable --now libvirtd
      ```
   4. 檢查 libvirtd 狀態
      ```bash
      systemctl status libvirtd 
      ```
   5. 配置橋接網路
      - 請執行下方指令並記錄欲使用之實體網卡之資訊 (i.e. MAC address, ipv4 address, GW...)
        ```bash 
        ip a 
        ```
      - 移除網卡
        ```bash
        nmcli con delete ['nic profile name'] 
        ```
      - 新增橋接網卡
        ```bash
        nmcli con add con-name ['name of bridge'] type bridge ifname ['name of bridge'] ipv4.address ['ipv4 address of the nic you deleted'] ipv4.gateway ['gateway of the nic you deleted'] ipv4.dns ['ipv4 address of OCP bastion'] ipv4.method manual 
        ```
        > i.e. nmcli con add con-name *br0* type bridge ifname *br0* ipv4.address *172.22.331.100* ipv4.gateway *172.22.331.10* ipv4.dns *172.22.331.100* ipv4.method manual 
      - 新增橋接網卡的 slave
        ```bash
        nmcli con add con-name ['name of slave'] ifname ['name of the removed nic'] master ['name of bridge'] type bridge-slave autoconnect yes 
        ```
        > i.e. nmcli con add con-name *br0-slave* ifname *ens23* master *br0* type bridge-slave autoconnect yes
      - 請執行下方指令，並確認橋接網卡與已移除之網卡的 MAC 地址相同
        ```bash
        ip a 
        ```
   6. 開啟 KVM 介面
      ``` 
      virt-manager 
      ```
   7. 點左上角帶有螢幕的按鈕，並選擇第一個選項後進下一步
      ![啟動 kvm](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-vii-start.png)
   8. 下一步要選擇安裝作業系統用的映像檔，但必須先新增 ISO 所在的路徑作為 pool。請點選 Browse 按鈕，你將會看見 Locate ISO media volume 視窗。點選左下角的加號按鈕，於彈出的視窗中為 pool 命名並選擇 ISO 存放的位置後，即可進入下一步
      ![建立 pool](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-viii-pool%26iso_1.png)
      ![選擇 ISO](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-viii-pool%26iso_2.png)
      ![確認位置後進入下一步](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-viii-pool&iso_3.png?raw=true)
   9. 選擇記憶體與核心數。順利完成安裝的最低規格為 8 核心、16384 MB 的記憶體
      ![選擇資源配置](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-ix-cpu&core.png?raw=true)
   10. 創建虛擬機儲存空間。最低規格不得低於 80 GB﹔若你有另外創建的存儲空間，請於第二個選項設定與配置
       ![選擇儲存配置](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-x-disk-storage.png?raw=true)
   11. 最後，請檢視您的虛擬機設定，並將網路選項設定為橋接裝置，並輸入其名稱。按下完成按鈕進入安裝程序
       ![設定橋接裝置](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-xi-config_check&nic.png?raw=true)
   12. 啟動剛剛建立的虛擬機，然後點擊左上角的燈泡圖示。選擇「開機選項」，並調整開機設備順序。請點擊 SATA CDROM1 方框，並將其設為優先順序
       ![啟動虛擬機](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-xii-boot_order.png?raw=true)
   13. 啟動虛擬機後，您可以按照一般流程安裝 RHEL
       ![安裝 RHEL](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-xiii-rhel_installation.png?raw=true)

3. 解開 OpenShift Automation 的 tar
   ```bash
   tar xzvf openshift-automation.tar.gz -C /root
   ```

4. 將 mirror 檔案放至/root/install_source/mirror
   ```bash
   ls -l /root/install_source/mirror
   
   mirror_seq1_000000.tar
   mirror_seq1_000000.tar.md5
   mirror_seq1_000001.tar
   mirror_seq1_000001.tar.md5
   ···
   ```

5. 檢查鏡像檔的md5是否一致
   ```bash
   sh /root/OpenShift-Automation/scripts/checkmd5_verify.sh check /root/install_source/mirror
   ```

6. 依客戶環境需求修改 OpenShift Automation 內的配置 (調整 /root/OpenShift-Automation/roles/ocp_bastion_installer/defaults/main.yml 內的配置)
    ```yaml
    ---
    online: false

    # compact or standard mode
    mode: compact

    # 依個人需求啟動或關閉防火牆與 SELinux 等服務與功能
    firewalld_disable: true
    selinux_disable: true 
    
    # 啟用或停用 DNS配置、網卡(NIC)名稱、DNS 上游伺服器位址
    dns_configure: true
    interface: ens33
    dns_upstream: 8.8.8.8
    
    # 是否 DNS 檢查
    dns_check: true
    dns_ip: 172.20.11.50
    
    # 是否啟用負載平衡配置
    haproxy_configure: true
    
    # 鏡像庫配置
    registry_configure: true
    mirrorRegistryDir: /root/install_source/mirror-registry.tar.gz
    quayRoot: /mirror-registry
    quayStorage: /mirror-registry/storage
    registryPassword: P@ssw0rd

    # NTP server
    ntp_server_configure: true
    # NTP client
    ntp_server_ip: 172.20.11.50
    
    # OCP 相關配置
    ocp_configure: true
    # 定義叢集名稱
    clusterName: ocp4
    # 定義叢集基礎域名
    baseDomain: demo.lab
    # 定義資源檔案之絕對路徑: 如公鑰、OCP 所需指令壓縮檔位置等
    sshKeyDir: /root/.ssh/id_rsa.pub
    ocpInstallDir: /root/install_source/openshift-install-rhel9-amd64.tar.gz
    ocpClientDir: /root/install_source/openshift-client-linux-amd64-rhel9-4.18.7.tar.gz
    # 連線安裝所需之 pull-secret 位置
    pullSecretDir: /root/install_source/pull-secret.txt
    
    # 從磁碟到鏡像的同步
    mirror: true
    ocmirrorSource: /root/install_source/oc-mirror.rhel9.tar.gz
    imageSetFile: /root/install_source/mirror
    reponame: ocp418
    
    # 節點的基本設定 (將不需要的節點註解掉)
    bastion:
      name: bastion
      ip: 172.20.11.50
    bootstrap:
      name: bootstrap
      ip: 172.20.11.60
    master:
    - name: master01
      ip: 172.20.11.51
    - name: master02
      ip: 172.20.11.52
    - name: master03
      ip: 172.20.11.53
    # standard mode nodes
    infra:
    - name: infra01
      ip: 172.20.11.54
    - name: infra02
      ip: 172.20.11.55
    - name: infra03
      ip: 172.20.11.56
    worker: 
    - name: worker01
      ip: 172.20.11.57
    - name: worker02
      ip: 172.20.11.58
    - name: worker03
      ip: 172.20.11.59
    ```

7. 執行 configure_and_run.sh 腳本並帶入 RHEL 版本
   ```bash
   sh /root/OpenShift-Automation/scripts/configure_and_run.sh 9.6
   ```

8. 設定節點網路連線
    1. 請於重新開機後，執行下列指令以 root 身分進行設定
       ```
       sudo -i
       ```
    2. 呼叫 nmtui
       ![呼叫nmtui](https://github.com/CCChou/OpenShift-Automation/blob/56c6724fc10b6b1d468fef64973b09d0d49e2bbf/images/1-nmtui.png)

    3. 選擇 Edit a connection
       ![選擇選項一](https://github.com/CCChou/OpenShift-Automation/blob/56c6724fc10b6b1d468fef64973b09d0d49e2bbf/images/2-choose_first_option_to_edit_connection.png)

    4. 選擇欲使用之網卡
       ![選擇網卡](https://github.com/CCChou/OpenShift-Automation/blob/350712014cfc03677daef5caee0072e6c8f9a375/images/3-choose_the_preferred_NiC.png)

    5. 編輯網卡連線資訊，完成後請按右下角之 OK 按鈕
       ![編輯連線](https://github.com/CCChou/OpenShift-Automation/blob/350712014cfc03677daef5caee0072e6c8f9a375/images/4-edit_connection.png)
       > 請注意! 若您的機器存有其他網卡，請*取消勾選*「不是提供給 OpenShift 使用」的網卡的 "Automatically connect" 選項! 並於 "Activate a connection" 選單中，將該張(或數張)網卡關閉。

    7. 選擇 Activate a connection
       ![選擇選項二](https://github.com/CCChou/OpenShift-Automation/blob/56c6724fc10b6b1d468fef64973b09d0d49e2bbf/images/5-choose_second_option.png)

    8. 重啟先前設定之網卡: 對網卡名稱連擊兩次回車鍵即可! 
       ![上下網卡](https://github.com/CCChou/OpenShift-Automation/blob/56c6724fc10b6b1d468fef64973b09d0d49e2bbf/images/6-reactivate_connection.png)

    9. 回到 nmtui 清單主頁面，點選 Quit 後輸入下方指令，以確認 Domain name 是否解析成功
       ```
       hostname
       ```
       ![解析檢查](https://github.com/CCChou/OpenShift-Automation/blob/56c6724fc10b6b1d468fef64973b09d0d49e2bbf/images/7-check_hostname.png)

9. 透過 curl 的方式呼叫 coreos-installer 執行 coreos install 指令
    - 在各個主機內執行 coreos-installer 腳本，執行順序 bootstrap > master > worker
      ```bash
      # 以下指令在 curl 執行後會自行執行，role 包含 bootstrap, master, worker
      # coreos-installer install ['device'] -I http://['bastion ip']:8080/['bootstrap/master/worker'].ign --insecure-ignition -n

      curl http://['bastion ip']:8080/install.sh | bash -s - ['device'] ['role']
      ```
      > 執行命令範例 (以 /dev/sda 及 bootstrap 為例): curl http://172.20.11.120:8080/install.sh | bash -s - /dev/sda bootstrap
    
    - 完成後重啟主機
      ```bash
      init 0 or poweroff
      ```
      > 若節點為虛擬機，請記得於開機前退出映像檔

### 安裝後配置流程

1. 配置 post_install.conf 內參數
   ```bash
   # post_install.conf

   # 總共的節點數量(包含 master)
   TOTAL_NODE_NUMBER=3

   # 使用的 CSI
   # nfs-csi: 預設沒有儲存的前提，僅適合一般 PoC
   # trident: 使用 NetApp Storage CSI
   CSI_MODULE=nfs-csi 

   # 安裝模式: 
   # standard: 叢集含有infra節點時
   # compact:  叢集沒有infra節點，即compact mode 或 3+2 節點
   INSTALL_MODE=compact
   REGISTRY=bastion.ocp.ansible.lab:8443
   GITEA_VERSION=1.21.7
   ```

2. 執行 post_install.sh 腳本
   ```bash
   sh /root/OpenShift-Automation/scripts/post_install.sh
   ```

3. 設定 gitea 和 argocd 的連線解析
   ```bash
   gitea-gitea-gitea.apps.${CLUSTER_DOMAIN}.${BASE_DOMAIN} ${BASTION_IP}
   openshift-gitops-server-openshift-gitops.apps.${CLUSTER_DOMAIN}.${BASE_DOMAIN} ${BASTION_IP}
   ```
   > 請注意，CLUSTER_DOMAIN BASE_DOMAIN BASTION_IP 三個參數可以參考 prep_script.conf 內填入的參數

4. 進入 gitea UI，註冊管理員帳號管理員帳號
   
   方法一、透過指令獲得 gitea 連線 URL
   ```bash
   TODO: oc get route 指令
   ```

   方法二、透過 Web UI 進入 gitea URL
   TODO: gitea 連線位置截圖

   進入 gitea 後註冊帳號
   ![](https://github.com/CCChou/OpenShift-Automation/blob/main/images/P4-2%20Register%20Gitea%20account.png)
   ![](https://github.com/CCChou/OpenShift-Automation/blob/main/images/P4-2-1%20Register%20Gitea%20account.png)
   
6. 配置 operators_install.conf 內參數
   ```bash
   # operators_install.conf

   # GIT Repo 參數
   GITEA_ADMIN=admin
   GITEA_PASSWORD=P%40ssw0rd # 注意，如果用 @ 的話，因字元關係，須將 @ 換成 %40

   # GITOPS 參數
   GITOPS_CLUSTER_TRYE=standard-with-virt # standard | standard-with-virt | platform-with-gpu
   OCP_ADMIN=ocpadmin
   GIT_REVISION=main
   ARGOCD_INSTALL_MODE=spoke # hub | spoke
   ```

7. 執行 operators_install.sh 腳本
   ```bash
   sh /root/OpenShift-Automation/scripts/operators_install.sh
   ```
