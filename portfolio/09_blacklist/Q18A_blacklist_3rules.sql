-- ============================================================
-- Q18-A. 블랙리스트 등록 대상 고객 탐지 — 해외이상 제외 (3 Rule)
-- ============================================================
-- [비즈니스 문제]
--   Q17-A 거래 단위 탐지를 고객 단위로 확장한다.
--   3가지 Rule 중 1개 이상에 해당하는 거래 이력이 있는 고객을
--   블랙리스트 등록 대상으로 선별한다.
--
--   [3가지 Rule]
--     Rule 1: 보이스피싱 (새벽 1~5시 + 모바일 + 50만원 이상)
--     Rule 2: 타지역 이상거래 (거주 도시 외 + 50만원 이상)
--     Rule 3: 고액 이상거래 (개인 평균 3배 이상)
--
-- [Q18-A vs Q18-B 비교 결과]
--   Q18-A: 135명 탐지
--   Q18-B: 136명 탐지 (해외이상 Rule 추가로 1명 더 탐지)
--   → 해외이상으로 추가된 1명: is_fraud = TRUE 확인 → 실제 fraud!
--
-- [사용 기술]
--   - Multi-CTE: 3개 Rule 독립 정의
--   - LEFT JOIN (DISTINCT customer_id): 고객 단위로 집계
--   - CASE WHEN 점수 합산: 위험패턴_수 계산
--   - WHERE 위험패턴_수A >= 1: 1개 이상 해당 고객 추출
-- ============================================================

WITH rule1 AS (
    SELECT txn_id, customer_id, txn_date,
           EXTRACT(HOUR FROM txn_date) AS txn_hour,
           amount, channel, is_fraud
    FROM fraud_transactions
    WHERE EXTRACT(HOUR FROM txn_date) BETWEEN 1 AND 5
      AND channel = '모바일'
      AND amount >= 500000
),
rule2 AS (
    SELECT ft.txn_id, ft.customer_id, ft.txn_date,
           ft.amount, ft.is_fraud,
           ft.city AS 거래도시, c.city AS 거주도시
    FROM fraud_transactions ft
    JOIN customers c ON ft.customer_id = c.customer_id
    WHERE ft.city != c.city
      AND ft.amount >= 500000
),
rule3 AS (
    SELECT txn_id, customer_id, txn_date, amount, channel, is_fraud
    FROM (
        SELECT *,
               AVG(amount) OVER (PARTITION BY customer_id) AS avg_amount
        FROM fraud_transactions
    ) AS summary
    WHERE amount >= 3 * avg_amount
)
SELECT customer_id, 위험패턴_수A
FROM (
    SELECT
        ft.customer_id,
        (CASE WHEN r1.customer_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN r2.customer_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN r3.customer_id IS NOT NULL THEN 1 ELSE 0 END) AS 위험패턴_수A
    FROM (SELECT DISTINCT customer_id FROM fraud_transactions) ft
    LEFT JOIN (SELECT DISTINCT customer_id FROM rule1) r1 ON r1.customer_id = ft.customer_id
    LEFT JOIN (SELECT DISTINCT customer_id FROM rule2) r2 ON r2.customer_id = ft.customer_id
    LEFT JOIN (SELECT DISTINCT customer_id FROM rule3) r3 ON r3.customer_id = ft.customer_id
) AS summary
WHERE 위험패턴_수A >= 1
ORDER BY 위험패턴_수A DESC;
