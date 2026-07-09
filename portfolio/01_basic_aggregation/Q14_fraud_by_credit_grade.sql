-- ============================================================
-- Q14. 신용등급별 Fraud 발생률 분석
-- ============================================================
-- [비즈니스 문제]
--   고객의 신용등급(credit_grade)에 따라 사기 피해 발생률이
--   어떻게 달라지는지 확인한다.
--   신용 리스크와 fraud 리스크의 상관관계를 파악할 수 있다.
--
-- [사용 기술]
--   - JOIN (customers ↔ fraud_transactions)
--   - GROUP BY + FILTER 조건부 집계
--   - ROUND()를 이용한 비율 계산
--
-- [FDS Insight]
--   신용등급이 낮은 고객군에서 fraud 발생률이 높다면
--   해당 등급 고객의 거래에 대해 추가 검증 단계를 적용하거나
--   거래 한도를 조정하는 정책 근거로 활용할 수 있다.
-- ============================================================

SELECT
    c.credit_grade,
    COUNT(*)                                                              AS 총거래건수,
    COUNT(*) FILTER (WHERE ft.is_fraud = TRUE)                           AS fraud_건수,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ft.is_fraud = TRUE)
               / COUNT(*), 2)                                            AS fraud_발생률
FROM fraud_transactions ft
JOIN customers c ON ft.customer_id = c.customer_id
GROUP BY c.credit_grade
ORDER BY fraud_발생률 DESC;
