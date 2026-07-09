-- ============================================================
-- Q15. 복합 조건 고위험 거래 탐지 + Rule 성능 평가
-- ============================================================
-- [비즈니스 문제]
--   단일 조건 Rule은 오탐이 많다. 여러 위험 신호가 동시에 나타날 때만
--   탐지하면 정탐 정밀도가 대폭 높아진다.
--   아래 4가지 조건을 모두 만족하는 거래를 '고위험 거래'로 분류하고,
--   이 Rule의 성능(정탐률 / 재현율 / 오탐률)을 함께 측정한다.
--
--   탐지 조건:
--     1) 새벽 시간대 (00~05시)
--     2) 거래금액 100만 원 이상
--     3) 비대면 채널 (모바일 또는 온라인)
--     4) 고객 개인 평균의 5배 이상
--
-- [사용 기술]
--   - CTE 1 (fraud_transactions_summary): 윈도우 함수로 고객별 평균 계산
--   - CTE 2 (rule2): 4가지 복합 조건 필터링
--   - FILTER 조건부 집계 + 스칼라 서브쿼리로 정탐률·재현율·오탐률 산출
--   - Window Function: AVG() OVER (PARTITION BY customer_id)
--
-- [FDS Insight]
--   4가지 조건을 동시에 만족하는 거래는 개별 Rule보다 훨씬 높은
--   Precision을 기대할 수 있다. 실시간 FDS에서 즉시 차단 대상을
--   선별하는 핵심 Rule로 활용 가능하다.
--   Q11의 단일 Rule 성능과 비교하면, 복합 조건 추가 시
--   정탐률이 얼마나 개선되는지 정량적으로 확인할 수 있다.
-- ============================================================

WITH fraud_transactions_summary AS (
    -- Step 1: 고객별 평균 거래금액 계산 (윈도우 함수)
    SELECT *,
        EXTRACT(HOUR FROM txn_date)                                     AS txn_hour,
        ROUND(AVG(amount) OVER (PARTITION BY customer_id), 2)           AS avg_amount
    FROM fraud_transactions
),
rule2 AS (
    -- Step 2: 4가지 복합 조건 동시 적용
    SELECT *
    FROM fraud_transactions_summary
    WHERE (txn_hour BETWEEN 0 AND 5)            -- 조건 1: 새벽 시간대
      AND amount >= 1000000                     -- 조건 2: 100만 원 이상
      AND channel IN ('모바일', '온라인')        -- 조건 3: 비대면 채널
      AND amount >= 5 * avg_amount              -- 조건 4: 개인 평균의 5배 이상
    ORDER BY amount DESC
)
-- Step 3: Rule 성능 평가 (정탐률 / 재현율 / 오탐률)
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
FROM rule2;
