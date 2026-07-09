-- ============================================================
-- Q05. 고객 1인당 평균 거래 건수 및 평균 금액 (서브쿼리 vs CTE 비교)
-- ============================================================
-- [비즈니스 문제]
--   고객 한 명이 평균적으로 얼마나 자주, 얼마 규모로 거래하는지
--   파악한다. 이 통계는 이후 이상거래 탐지(예: 고객 평균의 N배)의
--   기준값(Baseline)으로 활용된다.
--
-- [사용 기술]
--   - 서브쿼리(Subquery): FROM 절 내 인라인 뷰
--   - CTE (Common Table Expression): WITH 절로 가독성 향상
--   - 두 가지 방식을 나란히 비교하여 CTE의 장점을 직접 확인
--
-- [FDS Insight]
--   고객별 평균 거래 건수/금액을 Baseline으로 설정하면,
--   특정 고객이 평소와 크게 다른 패턴을 보일 때 이상 신호로 감지하는
--   개인화 탐지 Rule의 기초가 된다.
-- ============================================================

-- 방법 1: 서브쿼리 사용
SELECT
    ROUND(AVG(거래_건수), 2)    AS 고객_1인당_평균_거래건수,
    ROUND(AVG(평균_거래_금액), 2) AS 고객_1인당_평균_거래금액
FROM (
    SELECT
        customer_id,
        COUNT(txn_id)          AS 거래_건수,
        ROUND(AVG(amount), 2)  AS 평균_거래_금액
    FROM fraud_transactions
    GROUP BY customer_id
) AS customer_summary;


-- 방법 2: CTE 사용 (가독성 ↑, 재사용 용이)
WITH customer_summary AS (
    SELECT
        customer_id,
        COUNT(txn_id)          AS 거래_건수,
        ROUND(AVG(amount), 2)  AS 평균_거래_금액
    FROM fraud_transactions
    GROUP BY customer_id
)
SELECT
    ROUND(AVG(거래_건수), 2)      AS 고객_1인당_평균_거래건수,
    ROUND(AVG(평균_거래_금액), 2) AS 고객_1인당_평균_거래금액
FROM customer_summary;
