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

# 1. 시스템 업데이트 및 저장소 설정
echo "1. 시스템 업데이트 및 저장소 설정 중..."
if command -v dnf &> /dev/null; then
    # MySQL 저장소 비활성화 (존재하는 경우)
    if [ -f /etc/yum.repos.d/mysql-community.repo ]; then
        sudo sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/mysql-community.repo
    fi
    
    # 시스템 업데이트 (GPG 검증 비활성화)
    sudo dnf update -y --nogpgcheck
else
    # MySQL 저장소 비활성화 (존재하는 경우)
    if [ -f /etc/yum.repos.d/mysql-community.repo ]; then
        sudo sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/mysql-community.repo
    fi
    
    # 시스템 업데이트 (GPG 검증 비활성화)
    sudo yum update -y --nogpgcheck
fi

# 2. 방화벽 설정
echo -e "\n2. 방화벽 설정 중..."

# firewalld 설정
if command -v firewall-cmd &> /dev/null; then
    echo "- firewalld 설정 확인 중..."
    
    # firewalld 서비스가 실행 중인지 확인하고 실행
    if ! systemctl is-active --quiet firewalld; then
        echo "  - firewalld 서비스를 시작합니다."
        sudo systemctl enable --now firewalld
    fi
    
    # 포트가 이미 열려있는지 확인
    if ! sudo firewall-cmd --list-ports 2>/dev/null | grep -q '5432/tcp'; then
        echo "  - PostgreSQL 포트(5432)를 엽니다."
        sudo firewall-cmd --permanent --add-port=5432/tcp
        sudo firewall-cmd --reload
        echo "  - PostgreSQL 포트(5432)가 영구적으로 열렸습니다."
    else
        echo "  - PostgreSQL 포트(5432)가 이미 열려 있습니다."
    fi
    
    # SELinux 설정 (Oracle Linux/RHEL)
    if [ -f /etc/selinux/config ]; then
        echo "- SELinux 설정 확인 중..."
        if getenforce | grep -q "Enforcing"; then
            echo "  - SELinux가 Enforcing 모드입니다. PostgreSQL 포트를 허용합니다."
            if command -v dnf &> /dev/null; then
                sudo dnf install -y policycoreutils-python-utils
            else
                sudo yum install -y policycoreutils-python-utils
            fi
            sudo semanage port -a -t postgresql_port_t -p tcp 5432 2>/dev/null || \
            echo "  - semanage 명령 실행에 실패했습니다. 수동으로 확인이 필요할 수 있습니다."
        fi
    fi
else
    echo "- firewalld가 설치되어 있지 않습니다. 방화벽 설정을 위해 firewalld를 설치하세요."
    echo "  sudo yum install -y firewalld"
    echo "  sudo systemctl enable --now firewalld"
fi

# 3. PostgreSQL 설치
echo -e "\n3. PostgreSQL 설치 중..."

# PostgreSQL 저장소 설정
if command -v dnf &> /dev/null; then
    # Oracle Linux 8 이상
    echo "- PostgreSQL 저장소 설정 중..."
    
    # 기존 PostgreSQL 모듈 비활성화
    sudo dnf -qy module disable postgresql
    
    # PostgreSQL 공통 저장소 추가
    sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    
    # 설치 전 저장소 확인
    echo "- 사용 가능한 저장소 목록:"
    sudo dnf repolist | grep -i postgres
    
    # PostgreSQL 15 설치
    echo "- PostgreSQL 15 패키지 설치 중..."
    sudo dnf install -y postgresql15-server postgresql15-contrib postgresql15-devel
    
    # 데이터베이스 초기화
    echo "- 데이터베이스 초기화 중..."
    sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
    
    # 인증 설정 수정 (md5 인증 활성화)
    echo "- 인증 설정 수정 중..."
    sudo sed -i 's/ident/md5/g' /var/lib/pgsql/15/data/pg_hba.conf
    
    # 서비스 시작
    echo "- PostgreSQL 서비스 시작 중..."
    sudo systemctl enable --now postgresql-15
    sudo systemctl restart postgresql-15
else
    # Oracle Linux 7
    echo "- PostgreSQL 저장소 설정 중..."
    sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    
    # PostgreSQL 15 설치
    echo "- PostgreSQL 15 패키지 설치 중..."
    sudo yum install -y postgresql15-server postgresql15-contrib postgresql15-devel
    
    # 데이터베이스 초기화
    echo "- 데이터베이스 초기화 중..."
    sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
    
    # 인증 설정 수정 (md5 인증 활성화)
    echo "- 인증 설정 수정 중..."
    sudo sed -i 's/ident/md5/g' /var/lib/pgsql/15/data/pg_hba.conf
    
    # 서비스 시작
    echo "- PostgreSQL 서비스 시작 중..."
    sudo systemctl enable --now postgresql-15
    sudo systemctl restart postgresql-15
fi

# PostgreSQL 서비스 상태 확인
echo -e "\n- PostgreSQL 서비스 상태 확인 중..."
systemctl status postgresql-15 --no-pager

# 4. Oracle Instant Client 설치
echo -e "\n4. Oracle Instant Client 설치 중..."
if command -v dnf &> /dev/null; then
    sudo dnf install -y libaio unzip wget
else
    sudo yum install -y libaio unzip wget
fi

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
echo "   $ cd ~/postgre2adb/scripts"
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
