-- ============================================================
-- Q02. Fraud 유형별 건수 및 평균 금액 분석
-- ============================================================
-- [비즈니스 문제]
--   어떤 종류의 사기(fraud_type)가 가장 많이 발생하고,
--   각 유형의 평균 피해 금액은 얼마인지 파악한다.
--   유형별 특성을 이해하면 Rule 우선순위 설정에 도움이 된다.
--
-- [사용 기술]
--   - GROUP BY + COUNT + AVG 집계
--   - NULL 필터링 (정상 거래 제외)
--   - ORDER BY 정렬
--
-- [FDS Insight]
--   평균 금액이 높은 fraud 유형일수록 단건 피해액이 크므로
--   해당 유형에 대한 탐지 Rule을 우선적으로 강화해야 한다.
-- ============================================================

SELECT
    fraud_type,
    COUNT(*)               AS 건수,
    ROUND(AVG(amount), 2)  AS 평균_금액
FROM fraud_transactions
WHERE fraud_type IS NOT NULL
GROUP BY fraud_type
ORDER BY 평균_금액 DESC;

