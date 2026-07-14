-- ============================================================
-- 분석1. 시간대별 Fraud율 분석 → Rule 1 (새벽 조건) 근거
-- ============================================================
-- [분석 목적]
--   Rule 설계 전, 시간대가 fraud 발생과 실제로 연관이 있는지 데이터로 검증한다.
--   감에 의존한 Rule이 아닌, 분석 결과가 Rule 임계값의 근거가 되어야 한다.
--
-- [분석 결과]
--   새벽 1~5시: fraud율 18~28%로 전체 평균(12%)의 1.5~2.3배
--   → 새벽 1~5시를 Rule 1의 시간 조건으로 확정
--
-- [사용 기술]
--   - EXTRACT(HOUR): timestamp에서 시간(0~23) 추출
--   - FILTER 조건부 집계: 전체 건수 대비 fraud 건수 계산
--
-- [FDS Insight]
--   새벽 시간대는 고객 본인 확인이 어렵고 자동 거래(봇)가 많아
--   fraud 비율이 높다. 이 분석은 Q15, Q17의 시간 조건 설계 근거로 활용된다.
-- ============================================================

SELECT
    EXTRACT(HOUR FROM txn_date)                                                     AS 시간대,
    COUNT(*)                                                                         AS 총거래,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)                                          AS fraud_건수,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2)             AS fraud율
FROM fraud_transactions
GROUP BY 시간대
ORDER BY fraud율 DESC;
