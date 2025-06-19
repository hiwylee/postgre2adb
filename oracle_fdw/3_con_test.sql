-- Oracle Cloud Autonomous Database 연결 테스트 및 샘플 작업

-- 1. 연결 테스트
SELECT 'Oracle FDW 연결 성공!' as connection_status;

-- 2. Oracle Cloud의 기본 테이블 확인
-- USER_TABLES 뷰를 통해 사용 가능한 테이블 목록 조회
CREATE FOREIGN TABLE oracle_user_tables (
    table_name VARCHAR(128),
    tablespace_name VARCHAR(30),
    num_rows INTEGER,
    last_analyzed DATE
) SERVER oracle_server
OPTIONS (
    schema 'POSTGRES',
    table 'USER_TABLES'
);

-- 사용 가능한 테이블 목록 조회
SELECT table_name, num_rows, last_analyzed 
FROM oracle_user_tables 
ORDER BY table_name;

-- 3. Oracle Cloud에 샘플 테이블 생성 (Oracle에서 실행)
/*
Oracle Cloud SQL Developer Web 또는 APEX에서 다음 SQL 실행:

-- 고객 테이블 생성
CREATE TABLE POSTGRES.CUSTOMERS (
    customer_id NUMBER(10) PRIMARY KEY,
    first_name VARCHAR2(45) NOT NULL,
    last_name VARCHAR2(45) NOT NULL,
    email VARCHAR2(50),
    phone VARCHAR2(20),
    address_id NUMBER(10),
    active NUMBER(1) DEFAULT 1,
    create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 주문 테이블 생성
CREATE TABLE POSTGRES.ORDERS (
    order_id NUMBER(10) PRIMARY KEY,
    customer_id NUMBER(10),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMBER(10,2),
    status VARCHAR2(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES ADMIN.CUSTOMERS(customer_id)
);

-- 제품 테이블 생성
CREATE TABLE POSTGRES.PRODUCTS (
    product_id NUMBER(10) PRIMARY KEY,
    product_name VARCHAR2(100) NOT NULL,
    category_id NUMBER(10),
    price NUMBER(8,2),
    stock_quantity NUMBER(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 샘플 데이터 삽입
INSERT INTO ADMIN.CUSTOMERS VALUES (1, 'John', 'Doe', 'john.doe@email.com', '010-1234-5678', 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO ADMIN.CUSTOMERS VALUES (2, 'Jane', 'Smith', 'jane.smith@email.com', '010-2345-6789', 2, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO ADMIN.CUSTOMERS VALUES (3, 'Bob', 'Johnson', 'bob.johnson@email.com', '010-3456-7890', 3, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO ADMIN.PRODUCTS VALUES (1, '4K TV', 1, 999.99, 50, CURRENT_TIMESTAMP);
INSERT INTO ADMIN.PRODUCTS VALUES (2, 'Laptop', 2, 1299.99, 30, CURRENT_TIMESTAMP);
INSERT INTO ADMIN.PRODUCTS VALUES (3, 'Smartphone', 3, 699.99, 100, CURRENT_TIMESTAMP);

INSERT INTO ADMIN.ORDERS VALUES (1, 1, CURRENT_TIMESTAMP, 999.99, 'COMPLETED', CURRENT_TIMESTAMP);
INSERT INTO ADMIN.ORDERS VALUES (2, 2, CURRENT_TIMESTAMP, 1299.99, 'PENDING', CURRENT_TIMESTAMP);
INSERT INTO ADMIN.ORDERS VALUES (3, 3, CURRENT_TIMESTAMP, 699.99, 'SHIPPED', CURRENT_TIMESTAMP);

COMMIT;
*/

-- 4. PostgreSQL에서 Oracle 데이터 조회 테스트
-- 연결이 성공하면 다음 쿼리들이 작동함

-- Oracle 고객 데이터 조회
SELECT customer_id, first_name, last_name, email 
FROM oracle_customers 
LIMIT 5;

-- Oracle 주문 데이터 조회
SELECT order_id, customer_id, order_date, total_amount, status 
FROM oracle_orders 
ORDER BY order_date DESC 
LIMIT 5;

-- Oracle 제품 데이터 조회
SELECT product_id, product_name, price, stock_quantity 
FROM oracle_products 
ORDER BY price DESC 
LIMIT 5;

-- 5. 복합 쿼리 - PostgreSQL과 Oracle 데이터 조인
-- PostgreSQL의 local customer와 Oracle의 orders 조인
SELECT 
    pc.customer_id,
    pc.first_name,
    pc.last_name,
    COUNT(oo.order_id) as oracle_orders_count,
    COALESCE(SUM(oo.total_amount), 0) as total_oracle_spending
FROM customer pc
LEFT JOIN oracle_orders oo ON pc.customer_id = oo.customer_id
GROUP BY pc.customer_id, pc.first_name, pc.last_name
ORDER BY total_oracle_spending DESC;

-- 6. 성능 테스트 - 필터링이 Oracle에서 수행되는지 확인
EXPLAIN (ANALYZE, BUFFERS) 
SELECT customer_id, first_name, last_name 
FROM oracle_customers 
WHERE active = 1 
AND create_date >= TIMESTAMP '2024-01-01 00:00:00';

-- 7. 데이터 수정 테스트 (Oracle에 직접 적용)
-- 새 고객 추가
INSERT INTO oracle_customers (
    customer_id, first_name, last_name, email, active
) VALUES (
    1001, 'Test', 'User', 'test.user@email.com', 1
);

-- 고객 정보 업데이트
UPDATE oracle_customers 
SET email = 'updated.email@example.com' 
WHERE customer_id = 1001;

-- 업데이트 확인
SELECT * FROM oracle_customers WHERE customer_id = 1001;

-- 8. 트랜잭션 테스트
BEGIN;
    -- PostgreSQL 로컬 테이블에 데이터 추가
    INSERT INTO customer (customer_id, first_name, last_name, email) 
    VALUES (1001, 'Local', 'Customer', 'local@email.com');
    
    -- Oracle 테이블에 주문 추가
    INSERT INTO oracle_orders (order_id, customer_id, total_amount, status) 
    VALUES (1001, 1001, 99.99, 'NEW');
    
    -- 확인 후 커밋
    SELECT 'Transaction test completed' as result;
COMMIT;

-- 9. 에러 처리 및 연결 상태 확인
DO $$
BEGIN
    -- Oracle 연결 테스트
    PERFORM count(*) FROM oracle_customers LIMIT 1;
    RAISE NOTICE 'Oracle FDW 연결 성공';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Oracle FDW 연결 실패: %', SQLERRM;
END $$;

-- 10. 정리 작업
-- 테스트 데이터 삭제
DELETE FROM oracle_customers WHERE customer_id = 1001;
DELETE FROM oracle_orders WHERE order_id = 1001;
DELETE FROM customer WHERE customer_id = 1001;

SELECT 'Oracle Cloud FDW 테스트 완료' as final_message;