-- ============================================================
-- Q13. Fraud 유형별 주요 발생 시간대(새벽/오전/오후) 분석
-- ============================================================
-- [비즈니스 문제]
--   각 사기 유형이 하루 중 어느 시간대에 집중되는지 파악한다.
--   시간대별·유형별 패턴이 다르다면, 시간대를 고려한 복합 Rule을
--   설계할 수 있다.
--
-- [사용 기술]
--   - EXTRACT(HOUR FROM timestamp): 시간 추출
--   - CASE WHEN을 이용한 시간대 구분 (새벽/오전/오후)
--   - GROUP BY 다중 컬럼 집계
--
-- [FDS Insight]
--   특정 fraud 유형이 새벽에만 집중된다면 시간 조건을 해당 Rule에
--   추가하여 오탐(FP)을 줄이고 정탐 정밀도를 높일 수 있다.
-- ============================================================

SELECT
    CASE
        WHEN EXTRACT(HOUR FROM txn_date) BETWEEN 0 AND 5  THEN '새벽(00~05시)'
        WHEN EXTRACT(HOUR FROM txn_date) BETWEEN 6 AND 12 THEN '오전(06~12시)'
        ELSE                                                    '오후(13~23시)'
    END           AS 시간대,
    fraud_type,
    COUNT(*)      AS 거래건수
FROM fraud_transactions
WHERE fraud_type IS NOT NULL
GROUP BY 시간대, fraud_type
ORDER BY fraud_type, 거래건수 DESC;
