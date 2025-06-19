# PostgreSQL과 Oracle 연동 가이드

## 1. 시스템 요구사항
- Ubuntu 20.04/22.04 LTS 또는 Oracle Linux 8/9
- 최소 4GB RAM (8GB 권장)
- 20GB 이상의 디스크 여유 공간
- 루트 권한
- 방화벽 설정 권한 (firewalld 또는 ufw)

## 2. 시스템 설정

### 2.1 방화벽 설정 (firewalld - Oracle Linux/RHEL/CentOS)
```bash
# 방화벽 서비스 상태 확인
sudo systemctl status firewalld

# 방화벽이 비활성화된 경우 활성화
sudo systemctl enable --now firewalld

# PostgreSQL 포트(5432)가 이미 열려있는지 확인
if ! sudo firewall-cmd --list-ports | grep -q '5432/tcp'; then
    echo "PostgreSQL 포트(5432)를 엽니다."
    sudo firewall-cmd --permanent --add-port=5432/tcp
    sudo firewall-cmd --reload
else
    echo "PostgreSQL 포트(5432)가 이미 열려 있습니다."
fi

# 방화벽 설정 확인
sudo firewall-cmd --list-ports | grep 5432 || echo "PostgreSQL 포트(5432)가 아직 열려있지 않습니다. 수동으로 확인이 필요합니다."
```

### 2.2 방화벽 설정 (ufw - Ubuntu/Debian)
```bash
# ufw 활성화 (비활성화된 경우에만)
if ! sudo ufw status | grep -q 'Status: active'; then
    echo "UFW를 활성화합니다."
    sudo ufw --force enable
fi

# PostgreSQL 포트(5432)가 이미 허용되었는지 확인
if ! sudo ufw status | grep -q '5432/tcp'; then
    echo "PostgreSQL 포트(5432)를 엽니다."
    sudo ufw allow 5432/tcp
else
    echo "PostgreSQL 포트(5432)가 이미 허용되어 있습니다."
fi

# 방화벽 상태 확인
sudo ufw status | grep 5432 || echo "PostgreSQL 포트(5432)가 아직 허용되지 않았습니다. 수동으로 확인이 필요합니다."
```

### 2.3 SELinux 정책 설정 (필요시)
```bash
# SELinux 상태 확인
getenforce

# SELinux가 Enforcing 모드인 경우 PostgreSQL 포트 허용
sudo semanage port -a -t postgresql_port_t -p tcp 5432

# 또는 SELinux를 허용 모드로 변경 (테스트용)
sudo setenforce 0
# 영구적으로 변경하려면 /etc/selinux/config 수정
```

## 3. PostgreSQL 설치
```bash
# 패키지 목록 업데이트
sudo apt update

# PostgreSQL 및 개발 도구 설치
sudo apt install -y postgresql postgresql-contrib postgresql-server-dev-all
```

## 4. Oracle Instant Client 설치
```bash
# 필수 패키지 설치
sudo apt install -y libaio1 unzip

# Oracle Instant Client 다운로드
wget https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-basic-linux.x64-21.6.0.0.0dbru.zip
wget https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-sdk-linux.x64-21.6.0.0.0dbru.zip

# 압축 해제
unzip instantclient-basic-linux.x64-21.6.0.0.0dbru.zip
unzip instantclient-sdk-linux.x64-21.6.0.0.0dbru.zip

# 설치 디렉토리로 이동
sudo mkdir -p /opt/oracle
sudo mv instantclient_21_6 /opt/oracle/

# 환경 변수 설정
echo 'export ORACLE_HOME=/opt/oracle/instantclient_21_6' | sudo tee -a /etc/profile.d/oracle.sh
echo 'export LD_LIBRARY_PATH=$ORACLE_HOME:$LD_LIBRARY_PATH' | sudo tee -a /etc/profile.d/oracle.sh
echo 'export PATH=$ORACLE_HOME:$PATH' | sudo tee -a /etc/profile.d/oracle.sh
source /etc/profile.d/oracle.sh
```

## 5. oracle_fdw 설치
```bash
# 의존성 설치
sudo apt install -y build-essential

# oracle_fdw 다운로드
wget https://github.com/laurenz/oracle_fdw/archive/refs/tags/ORACLE_FDW_2_5_0.tar.gz
tar -xzf ORACLE_FDW_2_5_0.tar.gz
cd oracle_fdw-ORACLE_FDW_2_5_0/

# 빌드 및 설치
make
sudo make install

# PostgreSQL에 확장 기능 추가
sudo -u postgres psql -c "CREATE EXTENSION oracle_fdw;"
```

## 6. 테스트 환경 구성
```sql
-- 테스트 데이터베이스 생성
CREATE DATABASE test_oracle_fdw;

-- 테스트 사용자 생성
CREATE USER test_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE test_oracle_fdw TO test_user;

-- Oracle 서버 연결 설정
\c test_oracle_fdw
CREATE EXTENSION oracle_fdw;

-- Oracle 서버 연결
CREATE SERVER oracle_server
FOREIGN DATA WRAPPER oracle_fdw
OPTIONS (dbserver '//oracle_host:1521/ORCLCDB');

-- 사용자 매핑
CREATE USER MAPPING FOR test_user
SERVER oracle_server
OPTIONS (user 'oracle_user', password 'oracle_password');
```

## 7. 외부 테이블 생성 및 테스트
```sql
-- 외부 테이블 생성
CREATE FOREIGN TABLE remote_employees (
    emp_id integer OPTIONS (key 'true'),
    emp_name varchar(100),
    salary numeric(10,2),
    hire_date date
) SERVER oracle_server
OPTIONS (schema 'HR', table 'EMPLOYEES');

-- 데이터 조회 테스트
SELECT * FROM remote_employees LIMIT 10;

-- 데이터 삽입 테스트
INSERT INTO remote_employees (emp_id, emp_name, salary, hire_date)
VALUES (1001, '홍길동', 85000.00, '2023-01-15');
```

## 8. 문제 해결
### 일반적인 문제
1. **라이브러리 로드 오류**
   - `LD_LIBRARY_PATH`가 제대로 설정되었는지 확인
   - Oracle Instant Client 버전이 호환되는지 확인

2. **연결 거부 오류**
   - Oracle 서버 주소와 포트 확인
   - 방화벽 설정 확인

3. **권한 오류**
   - Oracle 사용자에게 적절한 권한이 부여되었는지 확인

## 9. 성능 최적화
- 배치 크기 조정
- 인덱스 활용
- 필요한 컬럼만 조회

## 10. 샘플 데이터베이스 설치 및 사용

### 10.1 샘플 데이터베이스 설치

PostgreSQL용 샘플 데이터베이스(dvdrental, pagila, northwind)를 설치하려면 다음 스크립트를 실행하세요:

```bash
# 스크립트 다운로드 (아직 받지 않은 경우)
wget https://raw.githubusercontent.com/yourusername/yourrepo/main/scripts/install_sample_databases.sh

# 실행 권한 부여
chmod +x install_sample_databases.sh

# 스크립트 실행 (루트 권한 필요)
sudo ./install_sample_databases.sh
```

이 스크립트는 다음과 같은 작업을 수행합니다:
1. 필요한 도구 설치 (wget, unzip, postgresql-contrib)
2. 세 가지 인기 있는 샘플 데이터베이스 설치:
   - dvdrental: DVD 대여점을 위한 샘플 데이터베이스
   - pagila: 영화 대여점을 위한 샘플 데이터베이스
   - northwind: 전자상거래를 위한 샘플 데이터베이스
3. 각 데이터베이스에 대한 사용자 권한 설정
4. 유용한 스크립트 생성

### 10.2 유용한 스크립트

설치가 완료되면 다음 스크립트들을 사용할 수 있습니다:

1. **데이터베이스 연결 테스트**
   ```bash
   ./test_connection.sh
   ```

2. **특정 데이터베이스의 테이블 목록 조회**
   ```bash
   ./list_tables.sh [데이터베이스_이름]
   예: ./list_tables.sh dvdrental
   ```

3. **샘플 쿼리 실행**
   ```bash
   ./run_sample_query.sh [데이터베이스_이름]
   예: ./run_sample_query.sh dvdrental
   ```

### 10.3 PostgreSQL 클라이언트 사용법

1. **psql로 데이터베이스에 연결**
   ```bash
   # postgres 사용자로 연결
   sudo -u postgres psql -d [데이터베이스_이름]
   
   # test_user로 연결
   psql -U test_user -d [데이터베이스_이름]
   ```

2. **자주 사용하는 psql 명령어**
   ```sql
   -- 데이터베이스 목록 보기
   \l
   
   -- 테이블 목록 보기
   \dt
   
   -- 테이블 구조 보기
   \d [테이블_이름]
   
   -- 쿼리 실행
   SELECT * FROM [테이블_이름] LIMIT 10;
   
   -- 종료
   \q
   ```

## 11. 보안 권장사항
- 강력한 암호 사용
- 최소 권한 원칙 적용
- 정기적인 백업
- 불필요한 사용자 계정 비활성화
- 신뢰할 수 있는 호스트에서만 접속 허용 (pg_hba.conf 설정)
