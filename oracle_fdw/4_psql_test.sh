#!/bin/bash
# PostgreSQL 컨테이너(oracle_fdw)에 접속하여 SQL 스크립트 실행 예시
# 환경: docker 컨테이너 이름 oracle_fdw, 기본 비밀번호 postgres

set -e

# 1. 컨테이너 내부에서 SQL 실행
# 예: 3_con_test.sql 파일을 컨테이너에 복사 후 실행

echo "[INFO] 3_con_test.sql 복사 및 실행"
docker cp 3_con_test.sql oracle_fdw:/tmp/3_con_test.sql

docker exec -u postgres oracle_fdw psql -d postgres -f /tmp/3_con_test.sql

echo "[INFO] 쿼리 실행 완료."

# 2. psql 클라이언트로 직접 접속 예시
# docker exec -it oracle_fdw psql -U postgres -d postgres
# (프롬프트에서 직접 쿼리 입력 가능)
