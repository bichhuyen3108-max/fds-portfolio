-- ============================================================
-- Q18-B. 블랙리스트 등록 대상 고객 탐지 — 해외이상 포함 (4 Rule)
-- ============================================================
-- [비즈니스 문제]
--   Q18-A에 해외이상 Rule(4일 이내 국내+해외 동시 사용)을 추가한 버전이다.
--   Q18-A에서 놓친 고객이 있는지 확인하고,
--   해외이상 Rule의 실제 탐지 효과를 검증한다.
--
--   [4가지 Rule]
--     Rule 1: 보이스피싱 (새벽 1~5시 + 모바일 + 50만원 이상)
--     Rule 2: 타지역 이상거래 (거주 도시 외 + 50만원 이상)
--     Rule 3: 고액 이상거래 (개인 평균 3배 이상)
--     Rule 4: 해외이상 (4일 이내 국내+해외 동시 사용)
--
-- [Q18-A vs Q18-B 검증 결과]
--   Q18-B에서 추가된 1명의 고객 검증:
--   → is_fraud = TRUE 확인: 실제 fraud 고객!
--   → 해외이상 Rule을 포함할 경우 이 고객을 탐지 가능
--
-- [비즈니스 시나리오별 선택]
--   Scenario A — FP cost 우선: Q18-A — FP 0건, 고객 135명
--   Scenario B — Recall 우선:  Q18-B — FP 7건, 고객 136명
--   ※ 각 기업의 실제 FDS 정책과 무관한 비용함수 기준 분석임
--
-- [사용 기술]
--   - Multi-CTE: 4개 Rule 독립 정의
--   - Self-JOIN (Rule 4): 국내/해외 거래 쌍 매칭
--   - LEFT JOIN (DISTINCT customer_id): 고객 단위 집계
--   - EXCEPT: Q18-A와 Q18-B 차이 고객 추출
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
),
rule4 AS (
    -- 해외이상: 4일 이내 국내+해외 동시 사용
    SELECT ft1.txn_id, ft1.customer_id, ft1.txn_date,
           ft1.amount, ft1.is_fraud,
           ft1.city AS 국내거래, ft2.city AS 해외거래
    FROM fraud_transactions ft1
    JOIN fraud_transactions ft2
        ON  ft1.customer_id = ft2.customer_id
        AND DATE(ft2.txn_date) BETWEEN DATE(ft1.txn_date)
                                   AND DATE(ft1.txn_date) + INTERVAL '4 day'
        AND DATE(ft2.txn_date) != DATE(ft1.txn_date)
    WHERE ft1.city IN ('부산', '인천', '대구', '제주', '대전', '광주', '수원', '서울')
      AND ft2.city IN ('미국', '중국', '유럽')
)
SELECT customer_id, 위험패턴_수B
FROM (
    SELECT
        ft.customer_id,
        (CASE WHEN r1.customer_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN r2.customer_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN r3.customer_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN r4.customer_id IS NOT NULL THEN 1 ELSE 0 END) AS 위험패턴_수B
    FROM (SELECT DISTINCT customer_id FROM fraud_transactions) ft
    LEFT JOIN (SELECT DISTINCT customer_id FROM rule1) r1 ON r1.customer_id = ft.customer_id
    LEFT JOIN (SELECT DISTINCT customer_id FROM rule2) r2 ON r2.customer_id = ft.customer_id
    LEFT JOIN (SELECT DISTINCT customer_id FROM rule3) r3 ON r3.customer_id = ft.customer_id
    LEFT JOIN (SELECT DISTINCT customer_id FROM rule4) r4 ON r4.customer_id = ft.customer_id
) AS summary
WHERE 위험패턴_수B >= 1
ORDER BY 위험패턴_수B DESC;
