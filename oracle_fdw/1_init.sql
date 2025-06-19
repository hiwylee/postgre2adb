-- init-oracle-fdw.sql
-- PostgreSQL 시작 시 자동으로 실행되는 Oracle FDW 설정 스크립트

-- DVD Rental 데이터베이스 생성 및 초기화
\c dvdrental;

-- Oracle FDW 확장 설치
CREATE EXTENSION IF NOT EXISTS oracle_fdw;

-- Oracle 서버 정의 (Oracle Cloud Autonomous Database)
CREATE SERVER IF NOT EXISTS oracle_server
    FOREIGN DATA WRAPPER oracle_fdw
    OPTIONS (
        dbserver '(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ap-seoul-1.oraclecloud.com))(connect_data=(service_name=yh0olybn5pqce4n_nf_medium.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))'
    );

-- 사용자 매핑 생성 (Oracle Cloud 계정)
DROP USER MAPPING IF EXISTS FOR postgres SERVER oracle_server;
CREATE USER MAPPING IF NOT EXISTS FOR postgres
    SERVER oracle_server
    OPTIONS (
        user 'POSTGRES',
        password 'Oracle_12345'
    );

-- Oracle에서 가져올 샘플 테이블들 정의
-- 1. Oracle 고객 테이블
CREATE FOREIGN TABLE IF NOT EXISTS oracle_customers (
    customer_id INTEGER,
    first_name VARCHAR(45),
    last_name VARCHAR(45),
    email VARCHAR(50),
    phone VARCHAR(20),
    address_id INTEGER,
    active INTEGER,
    create_date TIMESTAMP,
    last_update TIMESTAMP
) SERVER oracle_server
OPTIONS (
    schema 'POSTGRES',
    table 'CUSTOMERS'
);

-- 2. Oracle 주문 테이블
CREATE FOREIGN TABLE IF NOT EXISTS oracle_orders (
    order_id INTEGER,
    customer_id INTEGER,
    order_date TIMESTAMP,
    total_amount NUMERIC(10,2),
    status VARCHAR(20),
    created_at TIMESTAMP
) SERVER oracle_server
OPTIONS (
    schema 'POSTGRES', 
    table 'ORDERS'
);

-- 3. Oracle 제품 테이블
CREATE FOREIGN TABLE IF NOT EXISTS oracle_products (
    product_id INTEGER,
    product_name VARCHAR(100),
    category_id INTEGER,
    price NUMERIC(8,2),
    stock_quantity INTEGER,
    created_at TIMESTAMP
) SERVER oracle_server
OPTIONS (
    schema 'POSTGRES',
    table 'PRODUCTS'
);

-- DVD Rental 기본 테이블들 생성 (샘플)
CREATE TABLE IF NOT EXISTS category (
    category_id SERIAL PRIMARY KEY,
    name VARCHAR(25) NOT NULL,
    last_update TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS film (
    film_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    release_year INTEGER,
    rental_rate NUMERIC(4,2) DEFAULT 4.99,
    length INTEGER,
    rating VARCHAR(10) DEFAULT 'G',
    last_update TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS customer (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(45) NOT NULL,
    last_name VARCHAR(45) NOT NULL,
    email VARCHAR(50),
    active INTEGER DEFAULT 1,
    create_date TIMESTAMP DEFAULT NOW(),
    last_update TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rental (
    rental_id SERIAL PRIMARY KEY,
    rental_date TIMESTAMP DEFAULT NOW(),
    customer_id INTEGER REFERENCES customer(customer_id),
    return_date TIMESTAMP,
    last_update TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payment (
    payment_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customer(customer_id),
    rental_id INTEGER REFERENCES rental(rental_id),
    amount NUMERIC(5,2) NOT NULL,
    payment_date TIMESTAMP DEFAULT NOW()
);

-- 샘플 데이터 삽입
INSERT INTO category (name) VALUES 
    ('Action'), ('Comedy'), ('Drama'), ('Horror'), ('Sci-Fi')
ON CONFLICT DO NOTHING;

INSERT INTO film (title, description, release_year, rental_rate, length, rating) VALUES 
    ('The Matrix', 'A computer hacker learns the truth about reality', 1999, 3.99, 136, 'R'),
    ('Toy Story', 'A cowboy doll is profoundly threatened', 1995, 2.99, 81, 'G'),
    ('Inception', 'A thief who steals corporate secrets', 2010, 4.99, 148, 'PG-13')
ON CONFLICT DO NOTHING;

INSERT INTO customer (first_name, last_name, email) VALUES 
    ('John', 'Doe', 'john.doe@email.com'),
    ('Jane', 'Smith', 'jane.smith@email.com'),
    ('Bob', 'Johnson', 'bob.johnson@email.com')
ON CONFLICT DO NOTHING;

-- Oracle FDW를 활용한 뷰 생성
CREATE OR REPLACE VIEW customer_order_summary AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name as full_name,
    c.email,
    COUNT(o.order_id) as total_orders,
    COALESCE(SUM(o.total_amount), 0) as total_spent,
    MAX(o.order_date) as last_order_date
FROM customer c
LEFT JOIN oracle_orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email;

-- Oracle FDW 연결 상태 확인 함수
CREATE OR REPLACE FUNCTION check_oracle_connection()
RETURNS BOOLEAN AS $$
BEGIN
    PERFORM 1 FROM oracle_customers LIMIT 1;
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 권한 설정
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- 초기화 완료 메시지
SELECT 'Oracle FDW 초기화가 완료되었습니다.' as message;