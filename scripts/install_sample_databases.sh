#!/bin/bash

# 오류 발생 시 스크립트 중단
set -e

# 로그 파일 설정
LOG_FILE="install_sample_db_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== PostgreSQL 샘플 데이터베이스 설치 시작 ==="
echo "시작 시간: $(date)"
echo ""

# 1. 필요한 도구 설치
echo "1. 필요한 도구 설치 중..."
sudo apt update
sudo apt install -y wget unzip postgresql-contrib

# 2. 샘플 데이터베이스 다운로드 및 설치
install_sample_db() {
    local db_name=$1
    local download_url=$2
    local db_file=$(basename "$download_url")
    
    echo -e "\n=== ${db_name^^} 설치 시작 ==="
    
    # 데이터베이스가 이미 있는지 확인
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
        echo "- $db_name 데이터베이스가 이미 존재합니다. 건너뜁니다."
        return 0
    fi
    
    # 다운로드
    echo "- $db_name 데이터베이스 다운로드 중..."
    wget -q "$download_url" -O "$db_file"
    
    # 압축 해제 (필요한 경우)
    if [[ "$db_file" == *.zip ]]; then
        echo "- 압축 해제 중..."
        unzip -q "$db_file" -d "${db_file%.*}"
        cd "${db_file%.*}" || exit 1
    elif [[ "$db_file" == *.tar.gz ]]; then
        echo "- 압축 해제 중..."
        mkdir -p "${db_file%.tar.gz}"
        tar -xzf "$db_file" -C "${db_file%.tar.gz}" --strip-components=1
        cd "${db_file%.tar.gz}" || exit 1
    fi
    
    # 데이터베이스 생성
    echo "- $db_name 데이터베이스 생성 중..."
    sudo -u postgres createdb "$db_name"
    
    # 스키마 및 데이터 로드
    echo "- 데이터 로드 중..."
    
    # 파일 찾기 (restore.sql 또는 유사한 파일)
    local sql_file
    sql_file=$(find . -maxdepth 1 -type f \( -name "*.sql" -o -name "*.backup" \) | head -n 1)
    
    if [ -z "$sql_file" ]; then
        echo "- SQL 파일을 찾을 수 없습니다. 수동 설치가 필요할 수 있습니다."
        return 1
    fi
    
    # 파일 확장자에 따라 적절한 명령어 선택
    if [[ "$sql_file" == *.backup ]]; then
        sudo -u postgres pg_restore -d "$db_name" "$sql_file"
    else
        sudo -u postgres psql -d "$db_name" -f "$sql_file"
    fi
    
    # 권한 설정
    echo "- 권한 설정 중..."
    sudo -u postgres psql -d "$db_name" -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO test_user;"
    sudo -u postgres psql -d "$db_name" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO test_user;"
    
    echo "- $db_name 설치가 완료되었습니다."
    cd ..
}

# 3. 다양한 샘플 데이터베이스 설치
install_sample_db "dvdrental" "https://www.postgresqltutorial.com/wp-content/uploads/2019/05/dvdrental.zip"
install_sample_db "pagila" "https://github.com/devrimgunduz/pagila/archive/refs/tags/pg14.zip"
install_sample_db "northwind" "https://raw.githubusercontent.com/pthom/northwind_psql/46d5f8a64f396f87c2c95a43a1fdfb43a22b4d0c/northwind.sql"

# 4. 유용한 스크립트 생성
echo -e "\n=== 유용한 스크립트 생성 ==="

# 데이터베이스 연결 테스트 스크립트
cat > test_connection.sh << 'EOL'
#!/bin/bash
# 데이터베이스 연결 테스트 스크립트

echo "사용 가능한 데이터베이스 목록:"
sudo -u postgres psql -c "SELECT datname FROM pg_database WHERE datistemplate = false;"

echo -e "\n샘플 쿼리 실행 (dvdrental 데이터베이스의 테이블 목록 조회):"
sudo -u postgres psql -d dvdrental -c "\\dt"
EOL

# 테이블 목록 조회 스크립트
cat > list_tables.sh << 'EOL'
#!/bin/bash
# 데이터베이스의 테이블 목록을 조회하는 스크립트

if [ -z "$1" ]; then
    echo "사용법: $0 [데이터베이스_이름]"
    echo "예: $0 dvdrental"
    exit 1
fi

DB_NAME=$1
echo "$DB_NAME 데이터베이스의 테이블 목록:"
sudo -u postgres psql -d "$DB_NAME" -c "\\dt"
EOL

# 샘플 쿼리 실행 스크립트
cat > run_sample_query.sh << 'EOL'
#!/bin/bash
# 샘플 쿼리를 실행하는 스크립트

if [ -z "$1" ]; then
    echo "사용법: $0 [데이터베이스_이름]"
    echo "예: $0 dvdrental"
    exit 1
fi

DB_NAME=$1

echo "[$DB_NAME] 가장 많이 대여된 영화 TOP 10:"
sudo -u postgres psql -d "$DB_NAME" <<EOF
SELECT f.title, COUNT(*) AS rental_count
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
GROUP BY f.title
ORDER BY rental_count DESC
LIMIT 10;
EOF
EOL

# 실행 권한 부여
chmod +x test_connection.sh list_tables.sh run_sample_query.sh

# 설치 완료 메시지
echo -e "\n=== 설치가 완료되었습니다 ==="
echo "설치 로그: $PWD/$LOG_FILE"
echo -e "\n=== 사용 방법 ==="

echo "1. 데이터베이스 연결 테스트:"
echo "   $ ./test_connection.sh"

echo -e "\n2. 특정 데이터베이스의 테이블 목록 조회:"
echo "   $ ./list_tables.sh [데이터베이스_이름]"
echo "   예: ./list_tables.sh dvdrental"

echo -e "\n3. 샘플 쿼리 실행:"
echo "   $ ./run_sample_query.sh [데이터베이스_이름]"
echo "   예: ./run_sample_query.sh dvdrental"

echo -e "\n4. PostgreSQL 클라이언트로 연결:"
echo "   $ sudo -u postgres psql -d [데이터베이스_이름]"
echo "   예: sudo -u postgres psql -d dvdrental"

echo -e "\n5. 사용자로 연결 (test_user):"
echo "   $ psql -U test_user -d [데이터베이스_이름]"
echo "   예: psql -U test_user -d dvdrental"

echo -e "\n※ 패스워드가 필요한 경우 'testpass'를 입력하세요."
