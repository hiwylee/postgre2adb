-- 1. Oracle FDW 확장 설치 (PostgreSQL에서 실행)
CREATE EXTENSION oracle_fdw;

-- 2. Oracle 서버 정의 (Oracle Cloud Autonomous Database)
CREATE SERVER oracle_server
    FOREIGN DATA WRAPPER oracle_fdw
    OPTIONS (
        dbserver '(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ap-seoul-1.oraclecloud.com))(connect_data=(service_name=yh0olybn5pqce4n_nf_medium.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))'
    );

-- 3. 사용자 매핑 생성
CREATE USER MAPPING FOR postgres
    SERVER oracle_server
    OPTIONS (
        user 'admin',
        password 'Oracle_12345'
    );

-- 4. Foreign Table 생성 (Oracle 테이블을 PostgreSQL에서 접근)
-- 예: Oracle Cloud의 employees 테이블을 매핑
CREATE FOREIGN TABLE oracle_employees (
    employee_id INTEGER,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    salary NUMERIC(8,2),
    department_id INTEGER
) SERVER oracle_server
OPTIONS (
    schema 'ADMIN',           -- Oracle Cloud의 ADMIN 스키마
    table 'EMPLOYEES'         -- Oracle 테이블명
);

-- 5. DVD Rental 예제에 Oracle FDW 적용
-- Oracle의 고객 정보 테이블을 PostgreSQL DVD rental DB와 연결

-- Oracle 고객 테이블 매핑
CREATE FOREIGN TABLE oracle_customers (
    customer_id INTEGER,
    first_name VARCHAR(45),
    last_name VARCHAR(45),
    email VARCHAR(50),
    address_id INTEGER,
    active INTEGER,
    create_date TIMESTAMP,
    last_update TIMESTAMP
) SERVER oracle_server
OPTIONS (
    schema 'ADMIN',        -- Oracle Cloud ADMIN 스키마
    table 'CUSTOMERS'
);

-- 6. 데이터 조회 예제
-- PostgreSQL의 local 테이블과 Oracle의 foreign 테이블 조인
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    r.rental_date,
    f.title as film_title
FROM oracle_customers c
JOIN rental r ON c.customer_id = r.customer_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
WHERE c.active = 1
ORDER BY r.rental_date DESC
LIMIT 10;

-- 7. 데이터 삽입 (Oracle 테이블에 직접 삽입)
INSERT INTO oracle_customers (
    customer_id, first_name, last_name, email, 
    address_id, active, create_date
) VALUES (
    1001, 'John', 'Doe', 'john.doe@email.com',
    1, 1, NOW()
);

-- 8. 데이터 업데이트
UPDATE oracle_customers 
SET email = 'newemail@email.com' 
WHERE customer_id = 1001;

-- 9. 통계 및 분석 쿼리
-- PostgreSQL의 분석 함수와 Oracle 데이터 결합
WITH oracle_customer_stats AS (
    SELECT 
        COUNT(*) as total_customers,
        COUNT(CASE WHEN active = 1 THEN 1 END) as active_customers,
        AVG(CASE WHEN active = 1 THEN 1.0 ELSE 0.0 END) * 100 as active_percentage
    FROM oracle_customers
)
SELECT 
    ocs.*,
    COUNT(r.rental_id) as total_rentals
FROM oracle_customer_stats ocs
CROSS JOIN rental r
GROUP BY ocs.total_customers, ocs.active_customers, ocs.active_percentage;

-- 10. 성능 최적화를 위한 쿼리
-- Oracle 서버에서 필터링 수행
SELECT customer_id, first_name, last_name
FROM oracle_customers
WHERE active = 1
  AND create_date >= '2023-01-01';

-- 11. 트랜잭션 처리
BEGIN;
    -- PostgreSQL 로컬 테이블 업데이트
    INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
    VALUES (1001, 1, 12345, 4.99, NOW());
    
    -- Oracle 테이블 업데이트
    UPDATE oracle_customers 
    SET last_update = NOW() 
    WHERE customer_id = 1001;
COMMIT;

-- 12. 뷰 생성으로 복잡한 쿼리 단순화
CREATE VIEW customer_rental_summary AS
SELECT 
    oc.customer_id,
    oc.first_name,
    oc.last_name,
    oc.email,
    COUNT(r.rental_id) as rental_count,
    SUM(p.amount) as total_spent,
    MAX(r.rental_date) as last_rental_date
FROM oracle_customers oc
LEFT JOIN rental r ON oc.customer_id = r.customer_id
LEFT JOIN payment p ON r.rental_id = p.rental_id
WHERE oc.active = 1
GROUP BY oc.customer_id, oc.first_name, oc.last_name, oc.email;

-- 13. 스키마 정보 확인
-- Foreign 테이블의 구조 확인
\d oracle_customers

-- Oracle FDW 연결 상태 확인
SELECT * FROM pg_foreign_server WHERE srvname = 'oracle_server';
SELECT * FROM pg_user_mapping WHERE srvid = (
    SELECT oid FROM pg_foreign_server WHERE srvname = 'oracle_server'
);

-- 14. 에러 처리 및 디버깅
-- 연결 테스트
SELECT COUNT(*) FROM oracle_customers LIMIT 1;

-- 특정 조건으로 데이터 존재 확인
SELECT EXISTS(
    SELECT 1 FROM oracle_customers 
    WHERE customer_id = 1001
) as customer_exists;