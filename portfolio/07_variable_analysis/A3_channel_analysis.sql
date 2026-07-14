-- ============================================================
-- 분석3. 채널별 Fraud율 분석 → ATM 제외 조건 근거
-- ============================================================
-- [분석 목적]
--   채널(온라인/모바일/카드/ATM)이 fraud 발생에 영향을 미치는지 검증한다.
--   채널 단독으로 Rule을 설계할 수 있는지, 아니면 보조 조건으로만
--   활용 가능한지 판단한다.
--
-- [분석 결과]
--   온라인: fraud율 22.63%  /  카드: 15.17%
--   모바일: 12.09%          /  ATM:  0%
--
--   채널 단독 Rule 성능:
--   온라인만:           정탐률 22.63% / 재현율 46.21% / 오탐 417건
--   온라인+카드:        정탐률 19.04% / 재현율 75%    / 오탐 842건
--   온라인+카드+모바일: 정탐률 16.65% / 재현율 100%   / 오탐 1,322건
--
-- [결론]
--   채널 단독 Rule은 정탐률 16~22%로 너무 낮고 오탐이 과도함
--   → 단독 Rule 부적합, AND 조건의 보조 조건으로 활용
--   → ATM은 fraud율 0% → ATM 제외 조건(channel != 'ATM') 확정
--
-- [사용 기술]
--   - GROUP BY channel: 채널별 집계
--   - UNION ALL: 여러 채널 조건 성능을 한 화면에 비교
-- ============================================================

-- 채널별 fraud율 분석
SELECT
    channel,
    COUNT(*)                                                                         AS 총거래,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)                                          AS fraud_건수,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2)             AS fraud율
FROM fraud_transactions
GROUP BY channel
ORDER BY fraud율 DESC;

-- 채널 단독 Rule 성능 테스트
SELECT '온라인만' AS 채널조건,
    COUNT(*)                                                                         AS 총탐지,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)                                          AS 정탐,
    COUNT(*) FILTER (WHERE is_fraud IS NOT TRUE)                                     AS 오탐,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2)             AS 정탐률,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
         / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)       AS 재현율
FROM fraud_transactions WHERE channel = '온라인'

UNION ALL

SELECT '온라인+카드',
    COUNT(*), COUNT(*) FILTER (WHERE is_fraud = TRUE),
    COUNT(*) FILTER (WHERE is_fraud IS NOT TRUE),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
         / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)
FROM fraud_transactions WHERE channel IN ('온라인', '카드')

UNION ALL

SELECT '온라인+카드+모바일',
    COUNT(*), COUNT(*) FILTER (WHERE is_fraud = TRUE),
    COUNT(*) FILTER (WHERE is_fraud IS NOT TRUE),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE) / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
         / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)
FROM fraud_transactions WHERE channel IN ('온라인', '카드', '모바일')

ORDER BY 재현율 DESC;
