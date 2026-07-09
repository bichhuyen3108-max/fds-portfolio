-- ============================================================
-- Q06. 1시간 내 3건 이상 반복 거래 탐지 (카드복제 패턴)
-- ============================================================
-- [비즈니스 문제]
--   카드가 복제된 경우, 피해자가 인지하기 전에 짧은 시간 안에
--   여러 건의 거래가 빠르게 발생하는 경향이 있다.
--   동일 고객 ID로 1시간 이내에 3건 이상 거래가 몰린 경우를 탐지한다.
--
-- [사용 기술]
--   - Self-JOIN: 같은 테이블을 두 번 참조
--   - 시간 구간 필터: txn_date + INTERVAL '1 hour'
--   - HAVING을 이용한 집계 조건 필터
--
-- [FDS Insight]
--   단순 건수 기준 Rule이지만, 단기간 내 반복 거래 패턴은
--   실제 현장에서 카드복제 탐지에 높은 정탐률을 보이는 고전적인 Rule이다.
--   Self-JOIN은 윈도우 함수(LAG/LEAD)로도 구현 가능하며,
--   대용량에서는 윈도우 함수가 성능상 유리하다.
-- ============================================================

SELECT
    t1.customer_id,
    COUNT(t2.txn_id) AS 1시간내_거래건수
FROM fraud_transactions t1
JOIN fraud_transactions t2
    ON  t1.customer_id = t2.customer_id
    AND t2.txn_date >= t1.txn_date
    AND t2.txn_date <= t1.txn_date + INTERVAL '1 hour'
GROUP BY t1.customer_id
HAVING COUNT(t2.txn_id) >= 3
ORDER BY 1시간내_거래건수 DESC;
