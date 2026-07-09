-- ============================================================
-- Q10. 가입 후 7일 이내 고액 거래 신규 고객 탐지 (입회사기 패턴)
-- ============================================================
-- [비즈니스 문제]
--   실제 존재하지 않는 신원으로 카드를 발급받은 뒤
--   가입 직후 고액 거래를 일으키는 '입회사기(Enrollment Fraud)' 패턴을
--   탐지한다. 가입 후 7일 이내에 50만 원 이상 거래한 고객을 추출한다.
--
-- [사용 기술]
--   - JOIN (customers ↔ fraud_transactions)
--   - DATE()를 이용한 날짜 비교
--   - 날짜 산술: join_date + INTERVAL '7 day'
--   - BETWEEN을 이용한 날짜 구간 필터
--
-- [FDS Insight]
--   가입 초기의 고액 거래는 정상 고객에게서는 드문 패턴이다.
--   이 쿼리로 추출된 고객을 대상으로 추가 본인확인 절차를 적용하거나
--   거래를 보류 처리하는 Rule을 자동화할 수 있다.
-- ============================================================

SELECT
    c.customer_id,
    c.join_date,
    ft.txn_date,
    ft.amount
FROM customers c
JOIN fraud_transactions ft ON c.customer_id = ft.customer_id
WHERE DATE(ft.txn_date) BETWEEN c.join_date
                             AND (c.join_date + INTERVAL '7 day')
  AND ft.amount >= 500000
ORDER BY ft.amount DESC;
