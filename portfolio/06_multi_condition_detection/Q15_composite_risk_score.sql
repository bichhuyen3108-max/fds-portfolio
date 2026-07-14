-- ============================================================
-- Q15. AND 복합 조건 고위험 거래 탐지 + Rule 성능 평가
-- ============================================================
-- [비즈니스 문제]
--   단일 조건 Rule은 오탐이 많다. 변수 상관관계 분석(분석1~5)에서
--   데이터로 검증된 임계값을 기반으로 5가지 조건을 AND 결합하면
--   정탐 정밀도(Precision)가 대폭 높아진다.
--
--   [분석 기반 조건 설계]
--     조건 1 — 새벽 1~5시:  분석1에서 fraud율 18~28%로 최고
--     조건 2 — 50만원 이상: 분석2에서 정탐률 98.88%, 오탐 2건 최적
--     조건 3 — ATM 제외:    분석3에서 ATM fraud율 0% 확인
--     조건 4 — 타지역 거래: 분석4에서 타지역 fraud율 100%, 오탐 0건
--     조건 5 — 평균 3배 이상: 분석5에서 정탐률 100%, 오탐 0건
--
-- [사용 기술]
--   - CTE 1 (fraud_transactions_summary): 고객 거주도시 JOIN +
--     윈도우 함수로 고객별 평균 계산 + 시간 추출
--   - CTE 2 (rule2): 5가지 복합 조건 동시 필터링
--   - FILTER 조건부 집계 + 스칼라 서브쿼리로 정탐률·재현율·오탐률 산출
--
-- [결과 해석]
--   총탐지: 32건 / 정탐률: 100% / 재현율: 12.12% / 오탐: 0건
--   → AND 조건이 너무 엄격하여 재현율이 낮음
--   → 개선 방향: Q16에서 OR 조건으로 전환
--
-- [FDS Insight]
--   정탐률 100%, 오탐 0건 → 즉시 차단에 최적
--   단, 재현율 12.12%로 88%의 fraud를 놓침
--   → '차단 대상'은 이 Rule로, '모니터링 대상'은 Q16/Q17로 병행 운영
-- ============================================================

WITH fraud_transactions_summary AS (
    -- Step 1: 고객 거주도시 JOIN + 시간 추출 + 개인 평균 계산
    SELECT
        ft.*,
        EXTRACT(HOUR FROM ft.txn_date)                                  AS txn_hour,
        c.city                                                           AS 거주도시,
        ROUND(AVG(ft.amount) OVER (PARTITION BY ft.customer_id), 2)     AS avg_amount
    FROM fraud_transactions ft
    JOIN customers c ON ft.customer_id = c.customer_id
),
rule2 AS (
    -- Step 2: 5가지 AND 복합 조건 동시 적용
    SELECT *
    FROM fraud_transactions_summary
    WHERE (txn_hour BETWEEN 1 AND 5)         -- 조건 1: 새벽 1~5시 (fraud율 최고)
      AND amount >= 500000                   -- 조건 2: 50만원 이상 (정탐률 98.88%)
      AND channel != 'ATM'                  -- 조건 3: ATM 제외 (ATM fraud율 0%)
      AND amount >= 3 * avg_amount           -- 조건 4: 개인 평균의 3배 이상
      AND city != 거주도시                  -- 조건 5: 타지역 거래 (fraud율 100%)
    ORDER BY amount DESC
)
-- Step 3: Rule 성능 평가 (정탐률 / 재현율 / 오탐률)
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
FROM rule2;
