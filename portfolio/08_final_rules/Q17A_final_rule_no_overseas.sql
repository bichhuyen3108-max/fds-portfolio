-- ============================================================
-- Q17-A. 비즈니스 목적별 최종 Rule — 해외이상 제외 (3 Rule OR)
-- ============================================================
-- [비즈니스 문제]
--   Q15(AND)와 Q16(OR)의 분석 결과를 바탕으로,
--   'fraud 유형별 복합 조건을 OR로 연결'하는 최적화 Rule을 설계한다.
--   단순 OR이 아닌, 각 Rule이 단독으로도 의미 있는 복합 조건이다.
--
--   [3가지 Rule]
--     Rule 1 보이스피싱: 새벽 1~5시 + 모바일 채널 + 50만원 이상
--     Rule 2 타지역이상: 거주 도시와 다른 도시 + 50만원 이상
--     Rule 3 고액이상:   고객 개인 평균의 3배 이상
--
--   [방향 A vs B 비교]
--     방향 A (본 쿼리): 해외이상 Rule 제외 → 오탐(FP) 최소화 우선
--     방향 B (Q17B):   해외이상 Rule 포함 → Recall 향상 우선
--
-- [결과]
--   Precision: 100% / Recall: ~56% / FP: 0건
--   → FP 없이 실제 fraud만 탐지
--   → 정상 고객 차단 비용(FP cost)이 높은 비즈니스 환경에 적합한 선택
--      (절대적 최적이 아닌 비용함수 기준의 선택임)
--
-- [사용 기술]
--   - Multi-CTE: 3개 Rule을 독립 CTE로 분리
--   - LEFT JOIN + count_rule: Rule 해당 거래 합산
--   - WHERE count_rule >= 1: 1개 이상 Rule 해당 거래 추출
--   - FILTER + 스칼라 서브쿼리: 성능 지표 산출
--
-- [FDS Insight]
--   각 Rule은 변수 분석(A1~A5)으로 임계값이 검증된 조건이다.
--   이 Rule은 '즉시 차단 대상'으로 운영팀에 알림을 발송하는
--   실시간 FDS 엔진의 핵심 Rule로 활용 가능하다.
-- ============================================================

WITH rule1 AS (
    -- Rule 1: 보이스피싱 — 새벽 1~5시 + 모바일 + 50만원 이상
    SELECT txn_id, customer_id, txn_date,
           EXTRACT(HOUR FROM txn_date) AS txn_hour,
           amount, channel, is_fraud
    FROM fraud_transactions
    WHERE EXTRACT(HOUR FROM txn_date) BETWEEN 1 AND 5
      AND channel = '모바일'
      AND amount >= 500000
),
rule2 AS (
    -- Rule 2: 타지역 이상거래 — 거주 도시 외 + 50만원 이상
    SELECT ft.txn_id, ft.customer_id, ft.txn_date,
           ft.amount, ft.is_fraud,
           ft.city AS 거래도시, c.city AS 거주도시
    FROM fraud_transactions ft
    JOIN customers c ON ft.customer_id = c.customer_id
    WHERE ft.city != c.city
      AND ft.amount >= 500000
),
rule3 AS (
    -- Rule 3: 고액 이상거래 — 개인 평균의 3배 이상
    SELECT txn_id, customer_id, txn_date, amount, channel, is_fraud
    FROM (
        SELECT *,
               AVG(amount) OVER (PARTITION BY customer_id) AS avg_amount
        FROM fraud_transactions
    ) AS sub
    WHERE amount >= 3 * avg_amount
),
result AS (
    SELECT *
    FROM (
        SELECT ft.txn_id, ft.is_fraud,
               (CASE WHEN r1.txn_id IS NOT NULL THEN 1 ELSE 0 END
              + CASE WHEN r2.txn_id IS NOT NULL THEN 1 ELSE 0 END
              + CASE WHEN r3.txn_id IS NOT NULL THEN 1 ELSE 0 END) AS count_rule
        FROM fraud_transactions ft
        LEFT JOIN rule1 r1 ON r1.txn_id = ft.txn_id
        LEFT JOIN rule2 r2 ON r2.txn_id = ft.txn_id
        LEFT JOIN rule3 r3 ON r3.txn_id = ft.txn_id
    ) AS scored
    WHERE count_rule >= 1
)
SELECT
    COUNT(*)                                                                    AS 총탐지_수,
    COUNT(*) FILTER (WHERE is_fraud = TRUE)                                     AS 정탐_수,
    COUNT(*) FILTER (WHERE is_fraud IS NOT TRUE)                                AS 오탐_수,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
               / NULLIF(COUNT(*), 0), 2)                                        AS 정탐률_Precision,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
               / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud = TRUE), 2)
                                                                                AS 재현율_Recall,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud IS NOT TRUE)
               / (SELECT COUNT(*) FROM fraud_transactions WHERE is_fraud IS NOT TRUE), 2)
                                                                                AS 오탐률_FP_Rate
FROM result;
