#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "[실행] PostgreSQL 15 + oracle_fdw 컨테이너 실행"
docker run --name oracle_fdw -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d oracle_fdw
