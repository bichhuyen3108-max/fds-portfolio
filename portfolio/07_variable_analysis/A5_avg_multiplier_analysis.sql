-- ============================================================
-- 분석5. 개인 평균 배수 임계값 분석 → 3배 임계값 근거
-- ============================================================
-- [분석 목적]
--   '고객 개인 평균의 몇 배 이상'을 이상 거래로 볼 것인가?
--   2배/3배/4배/5배 임계값별 정탐률과 재현율을 비교하여
--   비즈니스 목표에 맞는 최적 임계값을 데이터로 도출한다.
--
-- [분석 배경]
--   fraud 평균금액(1,463,485원) vs 정상 평균금액(151,533원)
--   → fraud가 정상보다 평균 약 10배 높음
--   단, 정상 최대(96만원) > fraud 최소(5만원) → 겹치는 구간 존재
--   → 절대 금액이 아닌 '개인 평균 대비 배율'로 임계값 설정!
--
-- [분석 결과]
--   2배 이상: 총탐지 190건 / 정탐률 79.47% / 재현율 57.2%  / 오탐 39건
--   3배 이상: 총탐지  87건 / 정탐률 100%   / 재현율 32.95% / 오탐  0건 ← 최적
--   4배 이상: 총탐지  38건 / 정탐률 100%   / 재현율 14.39% / 오탐  0건
--   5배 이상: 총탐지  14건 / 정탐률 100%   / 재현율  5.3%  / 오탐  0건
--
-- [선택 근거 — 한패스/현대카드 기준]
--   정탐률/오탐 최소화 우선 → 3배 선택
--   정탐률 100% + 오탐 0건, 전체 Rule OR 조합으로 재현율 보완
--
-- [사용 기술]
--   - Window Function: AVG() OVER (PARTITION BY customer_id) — 개인 평균 계산
--   - UNION ALL: 여러 임계값 결과를 한 화면에 비교
--   - FILTER + 스칼라 서브쿼리: Precision / Recall 산출
-- ============================================================

-- fraud vs 정상 평균금액 기초 통계
SELECT
    is_fraud,
    ROUND(AVG(amount), 0)   AS 평균금액,
    ROUND(MIN(amount), 0)   AS 최소금액,
    ROUND(MAX(amount), 0)   AS 최대금액,
    COUNT(*)                AS 건수
FROM fraud_transactions
GROUP BY is_fraud;

-- 개인 평균 배수별 임계값 성능 비교
WITH customer_avg AS (
    SELECT customer_id, txn_id, amount, is_fraud,
           AVG(amount) OVER (PARTITION BY customer_id) AS avg_amount
    FROM fraud_transactions
)
SELECT '2배 이상' AS 임계값,
    COUNT(*)                                                                        AS 총탐지,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)                                          AS 정탐,
    COUNT(*) FILTER (WHERE is_fraud = FALSE)                                         AS 오탐,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2)             AS 정탐률,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)      AS 재현율
FROM customer_avg WHERE amount >= 2 * avg_amount

UNION ALL

SELECT '3배 이상',
    COUNT(*), COUNT(*) FILTER (WHERE is_fraud = TRUE),
    COUNT(*) FILTER (WHERE is_fraud = FALSE),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)
FROM customer_avg WHERE amount >= 3 * avg_amount

UNION ALL

SELECT '4배 이상',
    COUNT(*), COUNT(*) FILTER (WHERE is_fraud = TRUE),
    COUNT(*) FILTER (WHERE is_fraud = FALSE),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)
FROM customer_avg WHERE amount >= 4 * avg_amount

UNION ALL

SELECT '5배 이상',
    COUNT(*), COUNT(*) FILTER (WHERE is_fraud = TRUE),
    COUNT(*) FILTER (WHERE is_fraud = FALSE),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)
FROM customer_avg WHERE amount >= 5 * avg_amount

ORDER BY 재현율 DESC;
