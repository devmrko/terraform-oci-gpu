# OCI GPU VM 설정 및 모니터링 가이드

## 목차
1. [OCI 권한 설정](#1-oci-권한-설정)
2. [컨트롤 VM 설정](#2-컨트롤-vm-설정)
3. [GPU VM 구성](#3-gpu-vm-구성)
4. [모니터링 시스템 설정](#4-모니터링-시스템-설정)
5. [결과 확인](#5-결과-확인)

## 1. OCI 권한 설정

### API 키 생성 및 설정
1. OCI Console에서 사용자 프로필로 이동
2. API Keys 섹션에서 "Add API Key" 클릭
3. 새로운 키 페어 생성 또는 기존 키 업로드
4. 생성된 구성 파일 내용을 `~/.oci/config`에 저장

### 필요한 IAM 정책
```bash
Allow group [그룹명] to manage instance-family in compartment [컴파트먼트명]
Allow group [그룹명] to manage virtual-network-family in compartment [컴파트먼트명]
Allow group [그룹명] to manage volume-family in compartment [컴파트먼트명]
Allow group [그룹명] to manage object-family in compartment [컴파트먼트명]
```

### 환경 변수 설정
```bash
export TF_VAR_tenancy_ocid="your_tenancy_ocid"
export TF_VAR_user_ocid="your_user_ocid"
export TF_VAR_fingerprint="your_api_key_fingerprint"
export TF_VAR_private_key_path="~/.oci/oci_api_key.pem"
export TF_VAR_region="your_region"
```

## 2. 컨트롤 VM 설정

### VCN 및 서브넷 구성
- 필요한 포트 오픈:
  - 22 (SSH)
  - 3000 (Grafana)
  - 9090 (Prometheus)

### 필수 도구 설치

#### Terraform 설치
```bash
# Terraform 최신 버전 다운로드
curl -fsSL https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip -o terraform.zip

# 압축 해제 및 설치
unzip terraform.zip
sudo mv terraform /usr/local/bin/

# 설치 확인
terraform -v
```

#### Ansible 설치
```bash
sudo dnf install -y epel-release
sudo dnf install -y ansible
```

## 3. GPU VM 구성

### 사전 준비
1. terraform.tfvars 파일 수정
   - compartment_id
   - subnet_id
   - image_id (GPU 이미지)
   - instance_count (생성할 GPU VM 수)

2. GPU 이미지 OCID 확인
```bash
oci compute image list --compartment-id $COMP_ID --shape "VM.GPU.A10.1" --output table
```

### 배포 과정
1. SSH 키 페어 생성
```bash
./create_keypairs.sh
```

2. Terraform 실행
```bash
terraform init
terraform apply
```

3. 인벤토리 내역으로(VM이름, public IP, private key path) CSV로 생성
```bash
python generate_csv_and_inventory.py
```

### Ansible 플레이북 실행
1. 사용자 변경
```bash
./change_user.sh  # ubuntu → opc
```

2. Ansible 실행(ANSIBLE_HOST_KEY_CHECKING 제외 하도록)
```bash
./run-ansible.sh
```

### 스토리지 설정
Ansible playbook은 LVM을 사용하여 자동으로 스토리지를 용량을 지정된 용량으로 증가하도록 함:

1. 루트 디스크 확장 (Oracle Linux with LVM)
   - cloud-utils-growpart 유틸리티 설치
   - growpart를 사용하여 /dev/sda3 파티션 확장
   - pvresize로 물리 볼륨 크기 조정
   - /dev/ocivolume/root 논리 볼륨을 사용 가능한 모든 공간으로 확장
   - xfs_growfs로 XFS 파일시스템 확장

이 프로세스는:
- 파티션을 사용 가능한 최대 크기로 자동 확장
- LVM 구성 자동 조정
- 새로운 크기에 맞게 파일시스템 확장
- 시스템 안정성을 유지하기 위한 오류 처리 포함

이 스토리지 설정은 terraform.tfvars에서 지정한 볼륨 크기를 최대한 활용할 수 있도록 함

### 설치되는 구성요소
- 기본 패키지 (dnf)
- Miniconda
- NVIDIA CUDA 12.2
- Python AI/ML 라이브러리
- JupyterLab
- Node Exporter

### 포트 설정
- 22 (SSH)
- 8888 (Jupyter)
- 9100 (Node Exporter)

## 4. 모니터링 시스템 설정

### Prometheus 설치
```bash
# Prometheus 사용자 생성
sudo useradd --no-create-home --shell /bin/false prometheus

# 디렉토리 생성
sudo mkdir /etc/prometheus /var/lib/prometheus

# Prometheus 다운로드 및 설치
curl -LO https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
tar xvf prometheus-2.52.0.linux-amd64.tar.gz
cd prometheus-2.52.0.linux-amd64

# 바이너리 이동
sudo cp prometheus promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

# 설정 파일 이동
sudo cp -r consoles console_libraries prometheus.yml /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
```

#### Prometheus 서비스 설정
```bash
sudo tee /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
```

### Grafana 설치
```bash
# Grafana 저장소 추가
sudo tee /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=Grafana OSS
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
EOF

# Grafana 설치
sudo dnf install -y grafana

# Grafana 시작
sudo systemctl enable --now grafana-server
```

### 방화벽 설정
```bash
# Grafana 포트
sudo firewall-cmd --permanent --add-port=3000/tcp

# Prometheus 포트
sudo firewall-cmd --permanent --add-port=9090/tcp

# 설정 적용
sudo firewall-cmd --reload
```

### Prometheus 설정
```yaml
# /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']  # Node Exporter
```

## 5. 결과 확인

### 모니터링 확인
- Grafana: `http://<컨트롤VM-IP>:3000`
- Prometheus: `http://<컨트롤VM-IP>:9090/targets`

### 생성된 정보 확인
- VM 정보: `gpu_vm_list.csv` (VM 이름, Public IP, SSH 키)
- Jupyter 토큰: `ansible/jupyter_token.csv`

### Grafana 설정
1. Data Source로 Prometheus 추가
2. GPU 모니터링용 대시보드 생성

## 프로젝트 구조
```bash
terraform-oci-gpu/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars    # 구성 변수 설정 파일
├── scripts/
│   ├── create_keypairs.sh  # SSH 키 생성
│   ├── change_user.sh      # 사용자 변경 스크립트
│   └── run-ansible.sh      # Ansible 실행 스크립트
├── ansible/
│   ├── playbook.yml        # Ansible 작업 정의
│   ├── inventory.ini       # 자동 생성되는 인벤토리
│   └── jupyter_token.csv   # Jupyter 토큰 저장
└── utils/
    └── generate_csv_and_inventory.py  # 인벤토리 생성 스크립트
```

### 주요 파일 설정

#### terraform.tfvars
```hcl
compartment_id = "ocid1.compartment.oc1..."
subnet_id = "ocid1.subnet.oc1..."
image_id = "ocid1.image.oc1..."
shape = "VM.GPU.A10.1"
instance_count = 1  # 원하는 GPU VM 인스턴스 수 지정
```

#### ansible/playbook.yml 주요 태스크
```yaml
- name: Install required packages
  dnf:
    name:
      - gcc
      - kernel-devel
      - make
      - nvidia-driver
    state: present

- name: Install CUDA Toolkit
  # CUDA 설치 태스크

- name: Setup JupyterLab
  # JupyterLab 설정 태스크

- name: Install Node Exporter
  # 모니터링 설정 태스크
```

### 스크립트 실행 권한 설정
```bash
chmod +x scripts/*.sh
chmod +x utils/generate_csv_and_inventory.py
```

### 설정 파일 백업
```bash
# 중요 설정 파일 백업
cp terraform/terraform.tfvars terraform/terraform.tfvars.backup
cp ansible/inventory.ini ansible/inventory.ini.backup
```

### 로그 확인
- Terraform 로그: `terraform.log`
- Ansible 로그: `ansible/ansible.log`
- JupyterLab 로그: `/var/log/jupyter/jupyter.log`

### GPU 드라이버 확인
```bash
nvidia-smi  # GPU 상태 및 드라이버 버전 확인
```

### CUDA 설치 확인
```bash
nvcc --version  # CUDA 버전 확인
```

## 6. 문제 해결

### 일반적인 문제
1. Terraform 실행 오류
   - OCI 인증 정보 확인
   - 권한 설정 확인

2. GPU 드라이버 문제
   - 커널 헤더 설치 확인
   - NVIDIA 드라이버 재설치

3. 모니터링 문제
   - 포트 개방 확인
   - 서비스 상태 확인
   ```bash
   sudo systemctl status prometheus
   sudo systemctl status grafana-server
   ``` 
