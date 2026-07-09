-- ============================================================
-- Q08. 거주지와 다른 도시에서 발생한 거래 탐지 (타지역 이상거래)
-- ============================================================
-- [비즈니스 문제]
--   고객이 등록한 거주 도시와 실제 거래 발생 도시가 다른 경우,
--   도용 또는 타인 사용 가능성이 있다. 특히 고액 거래일수록
--   위험도가 높다.
--
-- [사용 기술]
--   - JOIN (customers ↔ fraud_transactions)
--   - 부등호 조건 비교 (c.city <> ft.city)
--   - ORDER BY 금액 내림차순
--
-- [FDS Insight]
--   거주지 외 지역 거래 자체는 정상일 수 있지만,
--   고액 + 새벽 + 타지역 등 복합 조건이 겹칠 때 위험도가 급상승한다.
--   이 쿼리를 복합 Rule의 서브쿼리로 활용하면 오탐을 줄일 수 있다.
-- ============================================================

SELECT
    c.customer_id,
    c.city               AS 거주도시,
    ft.city              AS 거래도시,
    ft.amount,
    ft.is_fraud
FROM fraud_transactions ft
JOIN customers c ON ft.customer_id = c.customer_id
WHERE c.city <> ft.city
ORDER BY ft.amount DESC;
