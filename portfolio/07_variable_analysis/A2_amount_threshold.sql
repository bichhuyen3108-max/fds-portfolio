-- ============================================================
-- 분석2. 금액 임계값별 Rule 성능 비교 → 50만원 임계값 근거
-- ============================================================
-- [분석 목적]
--   "얼마 이상"을 고액 거래로 볼 것인가? 임계값을 바꿔가며
--   정탐률(Precision)과 재현율(Recall)의 균형점을 데이터로 찾는다.
--
-- [분석 결과]
--   30만원: 정탐률 78.91% / 재현율 82.2%  / 오탐 58건
--   50만원: 정탐률 98.88% / 재현율 67.05% / 오탐  2건  ← 최적
--   100만원: 정탐률 100%  / 재현율 56.06% / 오탐  0건
--
-- [선택 근거 — 한패스/현대카드 기준]
--   카드사 주요 수익 = 카드 수수료
--   → 정상 고객 거래 차단 = 수익 손실 + 고객 이탈
--   → 오탐 최소화 우선 → 50만원 선택
--   (정탐률 98.88% + 재현율 67.05% + 오탐 2건)
--
-- [사용 기술]
--   - UNION ALL: 여러 임계값 결과를 세로로 결합
--   - FILTER + 스칼라 서브쿼리: Precision / Recall 동시 산출
-- ============================================================

SELECT
    '30만원 이상' AS 임계값,
    COUNT(*)                                                                        AS 총탐지,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)                                          AS 정탐,
    COUNT(*) FILTER (WHERE is_fraud = FALSE)                                         AS 오탐,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2)             AS 정탐률,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)      AS 재현율
FROM fraud_transactions WHERE amount >= 300000

UNION ALL

SELECT
    '50만원 이상',
    COUNT(*),
    COUNT(*) FILTER (WHERE is_fraud = TRUE),
    COUNT(*) FILTER (WHERE is_fraud = FALSE),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)
FROM fraud_transactions WHERE amount >= 500000

UNION ALL

SELECT
    '100만원 이상',
    COUNT(*),
    COUNT(*) FILTER (WHERE is_fraud = TRUE),
    COUNT(*) FILTER (WHERE is_fraud = FALSE),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)
FROM fraud_transactions WHERE amount >= 1000000

ORDER BY 재현율 DESC;
