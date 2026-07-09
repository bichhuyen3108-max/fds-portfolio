-- ============================================================
-- Q11. FDS Rule 성능 평가 — 정탐률 / 재현율 / 오탐률 측정
-- ============================================================
-- [비즈니스 문제]
--   Q07에서 설계한 '고객 평균의 5배 이상' Rule이 실제로 얼마나
--   정확하고 효과적인지 3가지 지표로 정량 평가한다.
--
--   ▸ 정탐률 (Precision)  = TP / (TP + FP)
--       Rule이 탐지한 건 중 실제 fraud인 비율
--       → 높을수록 오탐이 적고, 운영팀 부담이 줄어든다.
--
--   ▸ 재현율 (Recall)     = TP / 전체 실제 fraud 건수
--       실제 fraud 중 Rule이 잡아낸 비율
--       → 높을수록 놓치는 사기가 적다.
--
--   ▸ 오탐률 (FP Rate)    = FP / 전체 정상 거래 수
--       정상 거래 중 Rule이 잘못 탐지한 비율
--       → 낮을수록 불필요한 차단이 적다.
--
-- [사용 기술]
--   - Multi-CTE: 단계별 처리 분리 (평균 계산 → Rule 적용)
--   - Window Function: AVG() OVER (PARTITION BY customer_id)
--   - FILTER 조건부 집계 + 스칼라 서브쿼리를 이용한 분모 계산
--
-- [FDS Insight]
--   정탐률과 재현율은 트레이드오프 관계다.
--   임계값(5배)을 높이면 정탐률 ↑ / 재현율 ↓,
--   낮추면 재현율 ↑ / 정탐률 ↓.
--   운영 목표(피해 최소화 vs 오탐 최소화)에 따라
--   임계값 튜닝 방향을 결정하는 근거로 활용한다.
-- ============================================================

WITH customer_avg_amount AS (
    -- Step 1: 고객별 평균 거래금액을 윈도우 함수로 계산
    SELECT
        txn_id,
        customer_id,
        amount,
        is_fraud,
        ROUND(AVG(amount) OVER (PARTITION BY customer_id), 2) AS avg_amount
    FROM fraud_transactions
),
avg_more_than AS (
    -- Step 2: Rule 조건(평균의 5배 이상)에 해당하는 거래 필터링
    SELECT txn_id, customer_id, amount, avg_amount, is_fraud
    FROM customer_avg_amount
    WHERE amount > 5 * avg_amount
)
-- Step 3: 정탐률 / 재현율 / 오탐률 동시 산출
SELECT
    COUNT(*)                                                                AS 총탐지_수,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)                                 AS 정탐_수,
    COUNT(*) FILTER (WHERE is_fraud IS NOT TRUE)                            AS 오탐_수,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
               / COUNT(*), 2)                                               AS 정탐률_Precision,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
               / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)
                                                                            AS 재현율_Recall,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud IS NOT TRUE)
               / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = FALSE), 2)
                                                                            AS 오탐률_FP_Rate
FROM avg_more_than;
