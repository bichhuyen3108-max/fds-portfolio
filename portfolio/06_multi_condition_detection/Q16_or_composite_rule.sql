-- ============================================================
-- Q16. OR 복합 조건 고위험 거래 탐지 + Rule 성능 평가
-- ============================================================
-- [비즈니스 문제]
--   Q15(AND 규칙)는 정탐률 100%지만 재현율 12.12%로
--   88%의 fraud를 놓친다. 각 Rule을 OR로 결합하면
--   어느 하나라도 해당하는 거래를 모두 탐지할 수 있다.
--
--   [5가지 독립 Rule]
--     Rule 1: 새벽 1~5시 거래
--     Rule 2: 50만원 이상 거래
--     Rule 3: ATM 제외 채널 거래
--     Rule 4: 타지역(거주지 외) 거래
--     Rule 5: 고객 평균의 3배 이상 거래
--
-- [사용 기술]
--   - Multi-CTE: 5개 Rule을 독립 CTE로 분리
--   - LEFT JOIN + CASE WHEN: Rule 해당 여부를 0/1로 점수화
--   - WHERE count_rule >= 1: 1개 이상 Rule에 해당하는 거래 추출
--   - FILTER + 스칼라 서브쿼리: 성능 지표 산출
--
-- [결과 해석]
--   총탐지: 1,676건 / 정탐률: 15.75% / 재현율: 100% / 오탐: 1,412건
--   → OR 조건이 너무 넓어 정상 거래를 과도하게 포함
--   → AND(Q15): 정탐률 100% / 재현율 낮음 ↔ OR(Q16): 재현율 100% / 정탐률 낮음
--   → 개선 방향: Q17에서 fraud 유형별 복합 Rule을 OR로 연결
--
-- [FDS Insight]
--   OR 결합의 한계를 실제 수치로 확인할 수 있다.
--   채널(ATM 제외)처럼 식별력이 낮은 단독 조건이
--   OR에 포함되면 오탐이 급증함을 보여준다.
-- ============================================================

WITH rule1 AS (
    -- Rule 1: 새벽 1~5시 (fraud율 18~28%)
    SELECT txn_id, customer_id, txn_date,
           EXTRACT(HOUR FROM txn_date) AS txn_hour,
           amount, is_fraud
    FROM fraud_transactions
    WHERE EXTRACT(HOUR FROM txn_date) BETWEEN 1 AND 5
),
rule2 AS (
    -- Rule 2: 50만원 이상 (정탐률 98.88%, 오탐 2건)
    SELECT txn_id, customer_id, txn_date, amount, is_fraud
    FROM fraud_transactions
    WHERE amount >= 500000
),
rule3 AS (
    -- Rule 3: ATM 제외 (ATM fraud율 0%)
    SELECT txn_id, customer_id, txn_date, amount, channel, is_fraud
    FROM fraud_transactions
    WHERE channel != 'ATM'
),
rule4 AS (
    -- Rule 4: 타지역 거래 (fraud율 100%, 오탐 0건)
    SELECT ft.txn_id, ft.customer_id, ft.txn_date,
           ft.amount, ft.is_fraud,
           c.city  AS 거주도시,
           ft.city AS 거래도시
    FROM fraud_transactions ft
    JOIN customers c ON c.customer_id = ft.customer_id
    WHERE ft.city != c.city
),
rule5 AS (
    -- Rule 5: 고객 평균 3배 이상 (정탐률 100%, 오탐 0건)
    SELECT txn_id, customer_id, txn_date, amount, is_fraud, avg_amount
    FROM (
        SELECT *,
               ROUND(AVG(amount) OVER (PARTITION BY customer_id), 2) AS avg_amount
        FROM fraud_transactions
    ) AS sub
    WHERE amount >= 3 * avg_amount
),
result AS (
    -- 최종: 1개 이상 Rule 해당 거래 추출
    SELECT *
    FROM (
        SELECT ft.*,
               (CASE WHEN r1.txn_id IS NOT NULL THEN 1 ELSE 0 END
              + CASE WHEN r2.txn_id IS NOT NULL THEN 1 ELSE 0 END
              + CASE WHEN r3.txn_id IS NOT NULL THEN 1 ELSE 0 END
              + CASE WHEN r4.txn_id IS NOT NULL THEN 1 ELSE 0 END
              + CASE WHEN r5.txn_id IS NOT NULL THEN 1 ELSE 0 END) AS count_rule
        FROM fraud_transactions ft
        LEFT JOIN rule1 r1 ON ft.txn_id = r1.txn_id
        LEFT JOIN rule2 r2 ON ft.txn_id = r2.txn_id
        LEFT JOIN rule3 r3 ON ft.txn_id = r3.txn_id
        LEFT JOIN rule4 r4 ON ft.txn_id = r4.txn_id
        LEFT JOIN rule5 r5 ON ft.txn_id = r5.txn_id
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
