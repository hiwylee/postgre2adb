FROM postgres:15

ENV ORACLE_HOME=/opt/oracle/instantclient_21_6 \
    LD_LIBRARY_PATH=/opt/oracle/instantclient_21_6 \
    PATH=$PATH:/opt/oracle/instantclient_21_6 \
    TNS_ADMIN=/opt/oracle/network/admin

RUN apt-get update && apt-get install -y \
    build-essential \
    unzip \
    libaio1 \
    wget \
    git \
    postgresql-server-dev-15 \
    && rm -rf /var/lib/apt/lists/*

# 사전 다운로드된 ZIP 파일 복사


RUN wget https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-basic-linux.x64-21.6.0.0.0dbru.zip && \
    wget https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-sdk-linux.x64-21.6.0.0.0dbru.zip

# 압축 해제 및 설정
RUN unzip instantclient-basic-linux.x64-21.6.0.0.0dbru.zip -d /opt/oracle 
RUN     unzip instantclient-sdk-linux.x64-21.6.0.0.0dbru.zip -d /opt/oracle  
# RUN     ln -s $ORACLE_HOME/libclntsh.so.21 $ORACLE_HOME/libclntsh.so  
# RUN     ln -s $ORACLE_HOME/libocci.so.21 $ORACLE_HOME/libocci.so  
RUN     echo "$ORACLE_HOME" > /etc/ld.so.conf.d/oracle-instantclient.conf 
RUN     ldconfig

# # oracle_fdw clone & build
RUN git clone https://github.com/laurenz/oracle_fdw.git /oracle_fdw && \
    cd /oracle_fdw && \
    make && make install

COPY Wallet_NF.zip /tmp
RUN mkdir -p /opt/oracle/network/admin
RUN cd /opt/oracle/network/admin && unzip /tmp/Wallet_NF.zip


# PostgreSQL 초기화 스크립트 위치로 복사
RUN mkdir -p /docker-entrypoint-initdb.d

# DVDRENTAL 샘플 DB 다운로드 및 import script 생성
RUN wget -O /docker-entrypoint-initdb.d/dvdrental.tar \
    https://github.com/robconery/dvdrental/raw/master/dvdrental.tar

# 스크립트: 샘플 데이터 import 및 oracle_fdw extension 생성
RUN echo '#!/bin/bash\n\
pg_restore -U postgres -d postgres /docker-entrypoint-initdb.d/dvdrental.tar\n\
psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS oracle_fdw;"\n' \
> /docker-entrypoint-initdb.d/init.sh && chmod +x /docker-entrypoint-initdb.d/init.sh

# 5. PostgreSQL 환경에서 Oracle FDW 설정
# postgresql.conf에 추가
RUN echo "oracle_fdw.tns_admin = '/opt/oracle/network/admin'" >> /var/lib/postgresql/data/postgresql.conf

# 6. 연결 테스트 (선택사항)
# sqlplus admin/Oracle_12345@nf_medium

# 7. Docker 환경에서 Wallet 파일 마운트
# docker run 시 -v 옵션으로 Wallet 디렉토리 마운트
# -v /path/to/wallet:/opt/oracle/network/admin

VOLUME ["/var/lib/postgresql/data"]
EXPOSE 5432
