-- ============================================================
-- Q04. 새벽 시간대(00~05시) 거래 정상 vs Fraud 비교
-- ============================================================
-- [비즈니스 문제]
--   일반적으로 사기 거래는 본인 확인이 어려운 새벽 시간에 집중되는
--   경향이 있다. 00~05시 구간의 정상/사기 거래 비율을 확인하여
--   시간대 기반 Rule의 필요성을 검증한다.
--
-- [사용 기술]
--   - EXTRACT(HOUR FROM timestamp): 시간 추출
--   - BETWEEN을 이용한 시간 구간 필터링
--   - FILTER 조건부 집계
--
-- [FDS Insight]
--   새벽 시간대 fraud 비율이 전체 평균보다 높다면
--   해당 시간대 거래에 대해 추가 인증 요구나 임계값 하향 조정을
--   Rule로 적용하는 근거가 된다.
-- ============================================================

SELECT
    COUNT(*)                                          AS 총거래,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)           AS fraud_건수,
    COUNT(*) FILTER (WHERE is_fraud = FALSE)          AS 정상_건수
FROM fraud_transactions
WHERE EXTRACT(HOUR FROM txn_date) BETWEEN 0 AND 5;
