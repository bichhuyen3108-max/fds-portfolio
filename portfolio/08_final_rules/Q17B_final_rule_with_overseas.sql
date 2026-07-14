-- ============================================================
-- Q17-B. 비즈니스 목적별 최종 Rule — 해외이상 포함 (4 Rule OR)
-- ============================================================
-- [비즈니스 문제]
--   Q17-A에 해외이상 Rule(4일 이내 국내+해외 동시 사용)을 추가한 버전이다.
--   해외이상 Rule 추가 시 Recall이 향상되지만, FP가 일부 발생한다.
--   비즈니스 목표에 따라 Q17-A(FP 0건) vs Q17-B(Recall 향상) 중 선택한다.
--
--   [4가지 Rule]
--     Rule 1 보이스피싱:  새벽 1~5시 + 모바일 채널 + 50만원 이상
--     Rule 2 타지역이상:  거주 도시와 다른 도시 + 50만원 이상
--     Rule 3 해외이상:    4일 이내 국내+해외 동시 사용 (분석에서 4일째 fraud율 75%)
--     Rule 4 고액이상:    고객 개인 평균의 3배 이상
--
--   [Q17-A vs Q17-B 비교]
--     방향 A: FP 0건 유지, 단 fraud 1명 놓침 (FN 1건)
--     방향 B: FP 7건 추가, fraud 1명 추가 탐지 (is_fraud = TRUE 검증 완료)
--
-- [비즈니스 시나리오별 선택]
--   Scenario A — 정상 고객 차단 비용(FP cost)이 높은 경우: Q17-A 선택
--   Scenario B — fraud miss cost가 높아 Recall 우선인 경우: Q17-B 선택
--   ※ 각 기업의 실제 FDS 정책과 무관한 비용함수 기준 분석임
--
-- [사용 기술]
--   - Multi-CTE: 4개 Rule 독립 탐지
--   - Self-JOIN (Rule 3): 국내/해외 거래 쌍 매칭
--   - LEFT JOIN + count_rule: Rule 해당 여부 합산
-- ============================================================

WITH rule1 AS (
    -- Rule 1: 보이스피싱 — 새벽 1~5시 + 모바일 + 50만원 이상
    SELECT txn_id, customer_id, txn_date,
           EXTRACT(HOUR FROM txn_date) AS txn_hour,
           amount, channel, is_fraud
    FROM fraud_transactions
    WHERE EXTRACT(HOUR FROM txn_date) BETWEEN 1 AND 5
      AND channel = '모바일'
      AND amount >= 500000
),
rule2 AS (
    -- Rule 2: 타지역 이상거래 — 거주 도시 외 + 50만원 이상
    SELECT ft.txn_id, ft.customer_id, ft.txn_date,
           ft.amount, ft.is_fraud,
           ft.city AS 거래도시, c.city AS 거주도시
    FROM fraud_transactions ft
    JOIN customers c ON ft.customer_id = c.customer_id
    WHERE ft.city != c.city
      AND ft.amount >= 500000
),
rule3 AS (
    -- Rule 3: 해외이상 — 4일 이내 국내+해외 동시 사용
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
),
rule4 AS (
    -- Rule 4: 고액 이상거래 — 개인 평균의 3배 이상
    SELECT txn_id, customer_id, txn_date, amount, channel, is_fraud
    FROM (
        SELECT *,
               AVG(amount) OVER (PARTITION BY customer_id) AS avg_amount
        FROM fraud_transactions
    ) AS sub
    WHERE amount >= 3 * avg_amount
),
result AS (
    SELECT *
    FROM (
        SELECT ft.txn_id, ft.is_fraud,
               (CASE WHEN r1.txn_id IS NOT NULL THEN 1 ELSE 0 END
              + CASE WHEN r2.txn_id IS NOT NULL THEN 1 ELSE 0 END
              + CASE WHEN r3.txn_id IS NOT NULL THEN 1 ELSE 0 END
              + CASE WHEN r4.txn_id IS NOT NULL THEN 1 ELSE 0 END) AS count_rule
        FROM fraud_transactions ft
        LEFT JOIN rule1 r1 ON r1.txn_id = ft.txn_id
        LEFT JOIN rule2 r2 ON r2.txn_id = ft.txn_id
        LEFT JOIN rule3 r3 ON r3.txn_id = ft.txn_id
        LEFT JOIN rule4 r4 ON r4.txn_id = ft.txn_id
    ) AS scored
    WHERE count_rule >= 1
)
SELECT
    COUNT(*)                                                                    AS 총탐지_수,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)                                     AS 정탐_수,
    COUNT(*) FILTER (WHERE is_fraud IS NOT TRUE)                                AS 오탐_수,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
               / NULLIF(COUNT(*), 0), 2)                                        AS 정탐률_Precision,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
               / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)
                                                                                AS 재현율_Recall,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud IS NOT TRUE)
               / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud IS NOT TRUE), 2)
                                                                                AS 오탐률_FP_Rate
FROM result;
