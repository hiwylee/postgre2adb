# PostgreSQL 15 + oracle_fdw Docker

## 빌드 방법
```bash
./build.sh
```

## 실행 방법
```bash
./run.sh
or
docker run --name oracle_fdw -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d oracle_fdw
docker run --name oracle_fdw -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d oracle_fdw -v /path/to/wallet:/opt/oracle/network/admin

```

## rm docker container/image
```bash

docker rm oracle_fdw
docker rmi oracle_fdw

```

## 접속 정보
- 포트: 5432
- 기본 사용자: postgres
- 기본 비밀번호: postgres

## 확장 자동 생성
컨테이너가 처음 기동될 때 `oracle_fdw` 확장이 자동 생성됩니다.

## 이미지/컨테이너 이름
- 이미지 이름: `oracle_fdw`
- 컨테이너 이름: `oracle_fdw`

## 참고
- Oracle Instant Client 및 oracle_fdw는 오라클 라이선스 정책에 따라 사용하세요.
- Oracle DB 연결을 위해서는 별도의 Oracle 서버가 필요합니다.
