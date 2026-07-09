-- ============================================================
-- Q09. 같은 날 국내+해외 동시 거래 탐지 (카드복제 강력 의심)
-- ============================================================
-- [비즈니스 문제]
--   같은 날 국내와 해외에서 동시에 거래가 발생한다면,
--   물리적으로 한 사람이 두 곳에 있을 수 없으므로
--   카드 복제 또는 정보 도용이 강하게 의심된다.
--   해외 거래(미국·중국·유럽)와 국내 거래가 같은 날 겹치는 고객을 추출한다.
--
-- [사용 기술]
--   - Self-JOIN: 동일 고객의 거래를 국내/해외로 분리 비교
--   - DATE(): timestamp에서 날짜 부분만 추출하여 일치 여부 비교
--   - IN 연산자를 이용한 도시 목록 필터
--
-- [FDS Insight]
--   이 패턴은 금융권에서 '불가능 여행(Impossible Travel)'이라 부르는
--   고위험 시그널이다. 탐지 즉시 해당 거래를 보류하거나
--   고객에게 실시간 알림을 발송하는 자동화 Rule과 연계할 수 있다.
-- ============================================================

SELECT
    fd1.customer_id,
    fd1.txn_date                AS 국내_거래일시,
    fd2.txn_date                AS 해외_거래일시,
    fd1.city                    AS 국내_도시,
    fd2.city                    AS 해외_도시,
    fd1.amount                  AS 국내_금액,
    fd2.amount                  AS 해외_금액,
    fd1.is_fraud
FROM fraud_transactions fd1
JOIN fraud_transactions fd2
    ON  fd1.customer_id = fd2.customer_id
    AND DATE(fd1.txn_date) = DATE(fd2.txn_date)
WHERE fd2.city IN ('미국', '중국', '유럽')
  AND fd1.city IN ('서울', '부산', '인천', '대구', '대전', '광주', '수원', '제주')
ORDER BY fd1.customer_id, 국내_거래일시;
