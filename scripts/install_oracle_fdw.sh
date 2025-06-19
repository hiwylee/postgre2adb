#!/bin/bash

# 오류 발생 시 스크립트 중단
set -e

# 로그 파일 설정
LOG_FILE="oracle_fdw_install_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Oracle FDW 설치 시작 ==="
echo "시작 시간: $(date)"
echo ""

# 0. OS 확인
OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"' | cut -d. -f1)

echo "- OS: $OS_ID $OS_VERSION"

# 1. 시스템 업데이트
echo "1. 시스템 업데이트 중..."
sudo apt update
sudo apt upgrade -y

# 2. 방화벽 설정
echo -e "\n2. 방화벽 설정 중..."

# firewalld (Oracle Linux/RHEL/CentOS)
if command -v dnf &> /dev/null || command -v yum &> /dev/null; then
    echo "- firewalld 설정 확인 중..."
    sudo systemctl enable --now firewalld 2>/dev/null || true
    
    # 포트가 이미 열려있는지 확인
    if ! sudo firewall-cmd --list-ports 2>/dev/null | grep -q '5432/tcp'; then
        echo "  - PostgreSQL 포트(5432)를 엽니다."
        sudo firewall-cmd --permanent --add-port=5432/tcp 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        echo "  - PostgreSQL 포트(5432)가 영구적으로 열렸습니다."
    else
        echo "  - PostgreSQL 포트(5432)가 이미 열려 있습니다."
    fi
    
    # SELinux 설정 (Oracle Linux/RHEL)
    if [ -f /etc/selinux/config ]; then
        echo "- SELinux 설정 확인 중..."
        if getenforce | grep -q "Enforcing"; then
            echo "  - SELinux가 Enforcing 모드입니다. PostgreSQL 포트를 허용합니다."
            sudo yum install -y policycoreutils-python-utils 2>/dev/null || sudo dnf install -y policycoreutils-python-utils 2>/dev/null || true
            sudo semanage port -a -t postgresql_port_t -p tcp 5432 2>/dev/null || true
        fi
    fi
# ufw (Ubuntu/Debian)
elif command -v ufw &> /dev/null; then
    echo "- ufw 설정 확인 중..."
    
    # ufw가 비활성화된 경우에만 활성화
    if ! sudo ufw status | grep -q 'Status: active'; then
        echo "  - UFW를 활성화합니다."
        sudo ufw --force enable
    fi
    
    # 포트가 이미 허용되었는지 확인
    if ! sudo ufw status | grep -q '5432/tcp'; then
        echo "  - PostgreSQL 포트(5432)를 허용합니다."
        sudo ufw allow 5432/tcp
        echo "  - PostgreSQL 포트(5432)가 허용되었습니다."
    else
        echo "  - PostgreSQL 포트(5432)가 이미 허용되어 있습니다."
    fi
else
    echo "- 기본 방화벽이 감지되지 않았습니다. 수동으로 포트를 열어주세요."
fi

# 3. PostgreSQL 설치
echo -e "\n3. PostgreSQL 설치 중..."
sudo apt install -y postgresql postgresql-contrib postgresql-server-dev-all

# 4. Oracle Instant Client 설치
echo -e "\n4. Oracle Instant Client 설치 중..."
sudo apt install -y libaio1 unzip

# Oracle Instant Client 다운로드
echo "   - Oracle Instant Client 다운로드 중..."
wget -q https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-basic-linux.x64-21.6.0.0.0dbru.zip
wget -q https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-sdk-linux.x64-21.6.0.0.0dbru.zip

# 압축 해제
echo "   - 압축 해제 중..."
unzip -q instantclient-basic-linux.x64-21.6.0.0.0dbru.zip
unzip -q instantclient-sdk-linux.x64-21.6.0.0.0dbru.zip

# 설치 디렉토리로 이동
echo "   - 설치 디렉토리로 이동 중..."
sudo mkdir -p /opt/oracle
sudo mv instantclient_21_6 /opt/oracle/

# 환경 변수 설정
echo "   - 환경 변수 설정 중..."
echo 'export ORACLE_HOME=/opt/oracle/instantclient_21_6' | sudo tee -a /etc/profile.d/oracle.sh
echo 'export LD_LIBRARY_PATH=$ORACLE_HOME:$LD_LIBRARY_PATH' | sudo tee -a /etc/profile.d/oracle.sh
echo 'export PATH=$ORACLE_HOME:$PATH' | sudo tee -a /etc/profile.d/oracle.sh
source /etc/profile.d/oracle.sh

# 5. oracle_fdw 설치
echo -e "\n5. oracle_fdw 설치 중..."
sudo apt install -y build-essential

# oracle_fdw 다운로드
echo "   - oracle_fdw 다운로드 중..."
wget -q https://github.com/laurenz/oracle_fdw/archive/refs/tags/ORACLE_FDW_2_5_0.tar.gz
tar -xzf ORACLE_FDW_2_5_0.tar.gz
cd oracle_fdw-ORACLE_FDW_2_5_0/

# 빌드 및 설치
echo "   - 컴파일 중..."
make
sudo make install

# PostgreSQL에 확장 기능 추가
echo "   - PostgreSQL에 확장 기능 추가 중..."
sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS oracle_fdw;"

# 6. 테스트 환경 구성
echo -e "\n6. 테스트 환경 구성 중..."
sudo -u postgres psql -c "CREATE DATABASE test_oracle_fdw;"
sudo -u postgres psql -c "CREATE USER test_user WITH PASSWORD 'testpass';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE test_oracle_fdw TO test_user;"

# 설치 완료 메시지
echo -e "\n=== 설치가 완료되었습니다 ==="
echo "설치 로그: $PWD/$LOG_FILE"
echo "테스트 데이터베이스: test_oracle_fdw"
echo "테스트 사용자: test_user"

echo -e "\n=== 방화벽 설정 확인 ==="
if command -v firewall-cmd &> /dev/null; then
    echo "- firewalld 상태:"
    sudo firewall-cmd --list-ports | grep 5432 && echo "  ✅ PostgreSQL 포트(5432)가 열려 있습니다." || echo "  ❌ PostgreSQL 포트(5432)가 열려 있지 않습니다."
elif command -v ufw &> /dev/null; then
    echo "- ufw 상태:"
    sudo ufw status | grep 5432 && echo "  ✅ PostgreSQL 포트(5432)가 허용되었습니다." || echo "  ❌ PostgreSQL 포트(5432)가 허용되지 않았습니다."
else
    echo "- 설치된 방화벽이 감지되지 않았습니다. 수동으로 포트를 확인해주세요."
fi

echo -e "\n=== 다음 단계 ==="
echo "1. 샘플 데이터베이스 설치 (선택사항):"
echo "   $ cd ~/postgre/scripts"
echo "   $ chmod +x install_sample_databases.sh"
echo "   $ sudo ./install_sample_databases.sh"
echo -e "\n2. Oracle 서버 연결 설정:"
echo "   - guide/oracle_fdw_guide_ko.md 문서 참조"
echo -e "\n3. 보안 설정:"
echo "   - 기본 비밀번호 변경"
echo "   - pg_hba.conf 및 postgresql.conf 파일 검토 및 수정"
echo -e "\n4. 테스트:"
echo "   - 데이터베이스 연결 테스트: ./test_connection.sh"

echo -e "\n자세한 내용은 가이드 문서(guide/oracle_fdw_guide_ko.md)를 참조하세요."
