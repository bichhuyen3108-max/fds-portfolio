-- ============================================================
-- Q01. 전체 거래 중 Fraud 건수 및 비율 조회
-- ============================================================
-- [비즈니스 문제]
--   전체 거래 데이터에서 사기 거래(fraud)가 얼마나 발생하고 있는지
--   건수와 비율을 한눈에 파악한다.
--   FDS 운영의 첫 단계는 데이터 전체 현황 파악이다.
--
-- [사용 기술]
--   - 조건부 집계: CASE WHEN / FILTER (WHERE)
--   - ROUND()를 이용한 비율 계산
--
-- [FDS Insight]
--   Fraud 비율이 높은 경우 Rule 임계값을 낮춰 더 많은 거래를 탐지하고,
--   낮은 경우 오탐(FP)을 줄이는 방향으로 튜닝 기준을 설정할 수 있다.
-- ============================================================

-- 방법 1: CASE WHEN 사용
SELECT
    COUNT(*)                                                          AS 총거래건수,
    COUNT(CASE WHEN is_fraud = TRUE THEN 1 END)                      AS fraud_건수,
    ROUND(100.0 * COUNT(CASE WHEN is_fraud = TRUE THEN 1 END)
               / COUNT(*), 2)                                        AS fraud_percent
FROM fraud_transactions;

-- 방법 2: FILTER 사용 (PostgreSQL 권장 방식)
SELECT
    COUNT(*)                                                          AS 총거래건수,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)                          AS fraud_건수,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
               / COUNT(*), 2)                                        AS fraud_percent
FROM fraud_transactions;
