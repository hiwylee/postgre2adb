#!/bin/bash
set -e

echo "=== Oracle Linux 8: PostgreSQL 15 설치 스크립트 ==="
echo "실행 시간: $(date)"
echo

# 1. 시스템 패키지 업데이트
echo "[1/5] 시스템 패키지 업데이트"
sudo dnf -y update

# 2. 기존 PostgreSQL 모듈 비활성화
echo "[2/5] 기본 PostgreSQL 모듈 비활성화"
sudo dnf -qy module disable postgresql

# 3. PostgreSQL 공식 저장소 추가
echo "[3/6] PostgreSQL 공식 저장소 추가"
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# 4. PGDG 15 저장소 활성화
echo "[4/6] PGDG 15 저장소 활성화"
sudo dnf config-manager --set-enabled pgdg15

# 5. DNF 캐시 재생성
echo "[5/6] DNF 캐시 재생성"
sudo dnf clean all
sudo dnf makecache

# 6. PostgreSQL 15 서버 및 개발 패키지 설치
echo "[6/6] PostgreSQL 15 패키지 설치"
sudo dnf install -y postgresql15-server postgresql15-contrib postgresql15-devel

# 데이터베이스 초기화 및 서비스 시작
echo "- 데이터베이스 초기화 중..."
sudo /usr/pgsql-15/bin/postgresql-15-setup initdb

# 인증 방식(md5)으로 변경
echo "- 인증 방식(md5)으로 변경"
sudo sed -i 's/ident/md5/g' /var/lib/pgsql/15/data/pg_hba.conf
sudo systemctl enable --now postgresql-15
sudo systemctl restart postgresql-15

echo

sudo systemctl status postgresql-15 --no-pager
