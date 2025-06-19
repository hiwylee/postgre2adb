#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "[빌드] PostgreSQL 15 + oracle_fdw Docker 이미지"
docker build -t oracle_fdw .
echo "[완료] 이미지 이름: oracle_fdw"
