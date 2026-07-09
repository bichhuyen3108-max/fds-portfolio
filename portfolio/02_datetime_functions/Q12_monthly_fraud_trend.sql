-- ============================================================
-- Q12. 월별 Fraud 발생 추이 분석
-- ============================================================
-- [비즈니스 문제]
--   시간이 지남에 따라 사기 거래 발생 패턴이 어떻게 변하는지 파악한다.
--   특정 월에 fraud가 급증했다면 외부 이벤트(명절, 프로모션 등)와
--   연관성을 분석하거나 Rule 강화 시점을 결정하는 데 활용한다.
--
-- [사용 기술]
--   - DATE_TRUNC('month', timestamp): 월 단위 집계
--   - CTE를 이용한 전처리 분리
--   - FILTER 조건부 집계
--
-- [FDS Insight]
--   월별 fraud율 추이는 FDS Rule의 계절성 튜닝 근거가 된다.
--   특정 시기에 fraud 비율이 반복적으로 오른다면
--   해당 기간에 임시 Rule을 활성화하는 방식으로 대응할 수 있다.
-- ============================================================

WITH txn_by_month AS (
    SELECT
        DATE_TRUNC('month', txn_date) AS txn_month,
        is_fraud
    FROM fraud_transactions
)
SELECT
    txn_month,
    COUNT(*)                                                    AS 총거래,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)                     AS fraud_건수,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
               / COUNT(*), 2)                                   AS fraud율
FROM txn_by_month
GROUP BY txn_month
ORDER BY txn_month;
