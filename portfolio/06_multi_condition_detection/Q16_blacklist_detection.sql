-- ============================================================
-- Q16. 블랙리스트 등록 대상 고객 탐지 (다중 패턴 복합 리스크 스코어링)
-- ============================================================
-- [비즈니스 문제]
--   단일 이상 패턴만으로는 정상 고객을 과도하게 차단할 위험이 있다.
--   3가지 독립적인 fraud 패턴을 각각 탐지한 뒤,
--   2개 이상의 패턴에 해당하는 고객을 '고위험 고객'으로 분류하여
--   블랙리스트 등록 대상으로 선별한다.
--
--   탐지 패턴:
--     패턴 1: 1시간 내 반복 거래 이력 (카드복제 의심)
--     패턴 2: 고객 평균의 5배 이상 거래 이력 (이상 고액 거래)
--     패턴 3: 같은 날 국내+해외 동시 거래 이력 (불가능 여행)
--
-- [사용 기술]
--   - Multi-CTE: 3개 패턴을 각각 독립 CTE로 탐지
--   - Self-JOIN (패턴 1, 3): 같은 테이블을 조건별로 두 번 참조
--   - Window Function (패턴 2): AVG() OVER (PARTITION BY customer_id)
--   - LEFT JOIN + CASE WHEN: 패턴 해당 여부를 0/1 점수로 합산
--   - HAVING / WHERE: 합산 점수 ≥ 2인 고객만 최종 추출
--
-- [FDS Insight]
--   각 패턴은 Q06(반복 거래), Q07(고액 이상), Q09(동시 해외) 에서
--   이미 검증된 Rule이다. 이를 조합하면 개별 Rule보다 오탐이 적고,
--   실제 고위험 고객을 더 정확하게 선별할 수 있다.
--   Hanpass 같은 핀테크 FDS 환경에서 이 목록을
--   실시간 모니터링 차단 큐(Queue)와 연계할 수 있다.
-- ============================================================

WITH pattern1 AS (
    -- 패턴 1: 1시간 내 동일 고객의 반복 거래
    SELECT DISTINCT ft1.customer_id
    FROM fraud_transactions ft1
    JOIN fraud_transactions ft2
        ON  ft1.customer_id = ft2.customer_id
        AND ft2.txn_date >  ft1.txn_date
        AND ft2.txn_date <= ft1.txn_date + INTERVAL '1 hour'
        AND ft2.txn_id  != ft1.txn_id
),
pattern2 AS (
    -- 패턴 2: 고객 평균의 5배 이상 거래 이력
    SELECT DISTINCT customer_id
    FROM (
        SELECT
            customer_id,
            amount,
            ROUND(AVG(amount) OVER (PARTITION BY customer_id), 2) AS avg_amount
        FROM fraud_transactions
    ) AS sub
    WHERE amount >= 5 * avg_amount
),
pattern3 AS (
    -- 패턴 3: 같은 날 국내+해외 동시 거래 (불가능 여행)
    SELECT DISTINCT ft1.customer_id
    FROM fraud_transactions ft1
    JOIN fraud_transactions ft2
        ON  ft1.customer_id = ft2.customer_id
        AND DATE(ft1.txn_date) = DATE(ft2.txn_date)
    WHERE ft1.city IN ('서울', '부산', '인천', '대구', '대전', '광주', '수원', '제주')
      AND ft2.city IN ('미국', '중국', '유럽')
)
-- 최종: 패턴 합산 점수 ≥ 2 고객 → 블랙리스트 등록 대상
SELECT
    ft.customer_id,
    위험패턴_수,
    CASE
        WHEN p1.customer_id IS NOT NULL THEN 'Y' ELSE 'N'
    END AS 패턴1_반복거래,
    CASE
        WHEN p2.customer_id IS NOT NULL THEN 'Y' ELSE 'N'
    END AS 패턴2_고액이상,
    CASE
        WHEN p3.customer_id IS NOT NULL THEN 'Y' ELSE 'N'
    END AS 패턴3_동시해외
FROM (
    SELECT
        base.customer_id,
        (CASE WHEN p1.customer_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN p2.customer_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN p3.customer_id IS NOT NULL THEN 1 ELSE 0 END) AS 위험패턴_수
    FROM (SELECT DISTINCT customer_id FROM fraud_transactions) AS base
    LEFT JOIN pattern1 p1 ON base.customer_id = p1.customer_id
    LEFT JOIN pattern2 p2 ON base.customer_id = p2.customer_id
    LEFT JOIN pattern3 p3 ON base.customer_id = p3.customer_id
) AS scored
LEFT JOIN pattern1 p1 ON scored.customer_id = p1.customer_id
LEFT JOIN pattern2 p2 ON scored.customer_id = p2.customer_id
LEFT JOIN pattern3 p3 ON scored.customer_id = p3.customer_id
JOIN (SELECT DISTINCT customer_id FROM fraud_transactions) ft
    ON scored.customer_id = ft.customer_id
WHERE 위험패턴_수 >= 2
ORDER BY 위험패턴_수 DESC, ft.customer_id;
