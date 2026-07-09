

-- ============================================================
-- Q07. 고객 평균의 5배 이상 고액 거래 탐지 (개인화 이상거래 탐지)
-- ============================================================
-- [비즈니스 문제]
--   고객마다 소비 패턴(평균 거래 금액)이 다르기 때문에,
--   절댓값 임계치보다 '개인 평균 대비 배수'로 탐지하는 방식이
--   오탐을 줄이는 데 효과적이다.
--   고객 본인의 평균 거래 금액보다 5배 이상인 거래를 추출한다.
--
-- [사용 기술]
--   - Window Function: AVG() OVER (PARTITION BY customer_id)
--     → 전체 결과셋을 유지하면서 고객별 평균을 각 행에 함께 표시
--   - CTE: 윈도우 함수 결과를 가독성 있게 분리
--
-- [FDS Insight]
--   절대금액 기준 Rule은 고소득 고객에게 오탐이 많고
--   저소득 고객의 소액 이상거래를 놓칠 수 있다.
--   '개인 평균 N배' 방식은 고객 세그먼트에 관계없이
--   일관된 탐지 기준을 제공한다.
-- ============================================================

WITH customer_avg AS (
    SELECT
        customer_id,
        txn_id,
        amount,
        ROUND(AVG(amount) OVER (PARTITION BY customer_id), 2) AS 고객_평균금액
    FROM fraud_transactions
)
SELECT
    customer_id,
    txn_id,
    고객_평균금액,
    amount          AS 거래금액,
    ROUND(amount::NUMERIC / 고객_평균금액, 1) AS 평균_대비_배수
FROM customer_avg
WHERE amount > 5 * 고객_평균금액
ORDER BY 평균_대비_배수 DESC;
