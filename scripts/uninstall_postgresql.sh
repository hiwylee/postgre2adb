#!/bin/bash

# 오류 발생 시 스크립트 중단
set -e

echo "=== PostgreSQL 및 관련 패키지 제거 시작 ==="
echo "시작 시간: $(date)"
echo ""

# 1. PostgreSQL 서비스 중지
echo "1. PostgreSQL 서비스 중지 중..."
sudo systemctl stop postgresql 2>/dev/null || true

# 2. PostgreSQL 패키지 제거
echo -e "\n2. PostgreSQL 패키지 제거 중..."
if command -v dnf &> /dev/null; then
    echo "- dnf를 사용하여 PostgreSQL 제거"
    sudo dnf remove -y postgresql* \
        pgdg-redhat-repo \
        postgresql-* \
        pgadmin4* \
        pgpool* \
        pgbackrest \
        pg_repack \
        pgbouncer
    
    sudo dnf autoremove -y
    sudo dnf clean all
else
    echo "- yum을 사용하여 PostgreSQL 제거"
    sudo yum remove -y postgresql* \
        pgdg-redhat-repo \
        postgresql-* \
        pgadmin4* \
        pgpool* \
        pgbackrest \
        pg_repack \
        pgbouncer
    
    sudo yum autoremove -y
    sudo yum clean all
fi

# 3. PostgreSQL 데이터 디렉토리 제거
echo -e "\n3. PostgreSQL 데이터 디렉토리 제거 중..."
sudo rm -rf /var/lib/pgsql
sudo rm -rf /var/lib/pgadmin
sudo rm -rf /var/lib/pgpool

# 4. PostgreSQL 설정 파일 제거
echo -e "\n4. PostgreSQL 설정 파일 제거 중..."
sudo rm -rf /etc/postgresql*
sudo rm -rf /etc/pgpool*
sudo rm -rf /etc/sysconfig/pg*
sudo rm -rf /etc/systemd/system/postgresql*.service*

# 5. PostgreSQL 사용자 및 그룹 제거
echo -e "\n5. PostgreSQL 사용자 및 그룹 제거 중..."
if id -u postgres >/dev/null 2>&1; then
    sudo userdel -r postgres 2>/dev/null || true
    sudo groupdel postgres 2>/dev/null || true
fi

# 6. 시스템 설정 리로드
echo -e "\n6. 시스템 설정 리로드 중..."
sudo systemctl daemon-reload

# 7. Oracle FDW 관련 파일 제거 (선택 사항)
read -p "Oracle FDW 관련 파일도 제거하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "- Oracle Instant Client 제거 중..."
    sudo rm -rf /opt/oracle/instantclient_21_6
    sudo rm -f /etc/profile.d/oracle.sh
    
    echo "- oracle_fdw 소스 파일 제거 중..."
    rm -f ORACLE_FDW_2_5_0.tar.gz
    rm -f instantclient-*.zip
    
    # 환경 변수에서 제거
    if [ -f "$HOME/.bashrc" ]; then
        sed -i '/ORACLE_HOME/d' "$HOME/.bashrc"
        sed -i '/LD_LIBRARY_PATH.*oracle/d' "$HOME/.bashrc"
    fi
    
    if [ -f "$HOME/.bash_profile" ]; then
        sed -i '/ORACLE_HOME/d' "$HOME/.bash_profile"
        sed -i '/LD_LIBRARY_PATH.*oracle/d' "$HOME/.bash_profile"
    fi
    
    echo "- 환경 변수에서 Oracle 관련 설정이 제거되었습니다."
    echo "  변경 사항을 적용하려면 새 터미널을 열거나 다음 명령을 실행하세요:"
    echo "  source ~/.bashrc"
fi

echo -e "\n=== PostgreSQL 제거가 완료되었습니다 ==="
echo "완료 시간: $(date)"
echo ""
echo "주의: 방화벽 설정은 자동으로 제거되지 않습니다."
echo "방화벽 설정을 되돌리려면 다음 명령을 사용하세요:"
echo "  sudo firewall-cmd --permanent --remove-port=5432/tcp"
echo "  sudo firewall-cmd --reload"
echo ""
