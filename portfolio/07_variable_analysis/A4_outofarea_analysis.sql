-- ============================================================
-- 분석4. 타지역 거래 Fraud율 분석 → Rule 4 (타지역 조건) 근거
-- ============================================================
-- [분석 목적]
--   고객 거주 도시와 거래 발생 도시가 다를 때 fraud율이 높은지 확인한다.
--   타지역 거래가 단독으로 강력한 Rule이 될 수 있는지 검증한다.
--
-- [분석 결과]
--   타지역 거래: 총 193건 중 fraud 193건 → fraud율 100% ← 완벽한 신호!
--   거주지 거래: 총 1,807건 중 fraud 71건 → fraud율 3.93%
--
--   타지역 단독 Rule 성능:
--   총탐지: 193건 / 정탐: 193건 / 오탐: 0건
--   정탐률: 100% / 재현율: 73.11%
--
-- [결론]
--   타지역 거래는 정탐률 100%, 오탐 0건으로
--   포트폴리오 내 가장 강력한 단독 fraud 시그널!
--   → Rule 4 (타지역 조건) 확정
--
-- [FDS Insight]
--   고객이 거주지가 아닌 타지역에서 거래 발생
--   → 카드 도난 또는 복제 가능성 높음
--   → 즉시 모니터링 및 추가 인증 필요
--   → Q15 AND Rule, Q17 최종 Rule에 핵심 조건으로 포함
--
-- [사용 기술]
--   - JOIN customers: 거주 도시 데이터와 연결
--   - CASE WHEN: 타지역/거주지 분류
--   - FILTER + 스칼라 서브쿼리: Precision / Recall 산출
-- ============================================================

-- 타지역 vs 거주지 거래 fraud율 비교
SELECT
    CASE WHEN ft.city != c.city THEN '타지역' ELSE '거주지' END   AS 지역_구분,
    COUNT(*)                                                       AS 총거래,
    COUNT(*) FILTER (WHERE ft.is_fraud = TRUE)                     AS fraud_건수,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ft.is_fraud = TRUE)
               / COUNT(*), 2)                                      AS fraud율
FROM fraud_transactions ft
JOIN customers c ON ft.customer_id = c.customer_id
GROUP BY 지역_구분
ORDER BY fraud율 DESC;

-- 타지역 단독 Rule 성능 평가
SELECT
    '타지역 단독 Rule'                                             AS Rule명,
    COUNT(*)                                                       AS 총탐지,
    COUNT(*) FILTER (WHERE ft.is_fraud = TRUE)                     AS 정탐,
    COUNT(*) FILTER (WHERE ft.is_fraud IS NOT TRUE)                AS 오탐,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ft.is_fraud = TRUE)
               / COUNT(*), 2)                                      AS 정탐률,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ft.is_fraud = TRUE)
               / (SELECT COUNT(*) FROM fraud_transactions
                  WHERE is_fraud = TRUE), 2)                       AS 재현율
FROM fraud_transactions ft
JOIN customers c ON ft.customer_id = c.customer_id
WHERE ft.city != c.city;
