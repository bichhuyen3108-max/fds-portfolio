-- ============================================================
-- Q09. 4일 이내 국내+해외 동시 사용 탐지 (카드복제 강력 의심)
-- ============================================================
-- [비즈니스 문제]
--   해외에서 거래가 발생한 후 4일 이내에 국내에서도 거래가 있다면
--   (또는 그 반대), 물리적으로 이동 시간이 불충분한 경우 카드 복제 또는
--   정보 도용이 의심된다. 같은 날(DATE =)보다 확장된 4일 창을
--   적용하여 더 많은 의심 패턴을 포착한다.
--
-- [변경 이력]
--   이전 버전: 같은 날(DATE(fd1.txn_date) = DATE(fd2.txn_date)) 조건
--   현재 버전: 4일 이내 창 (DATE(fd2.txn_date) BETWEEN DATE(fd1.txn_date)
--              AND DATE(fd1.txn_date) + INTERVAL '4 day')
--              + 같은 날 제외 (DATE ≠ DATE) 조건 추가
--              → 분석5 검증에서 4일째 fraud율 75%로 가장 높음을 확인
--
-- [사용 기술]
--   - Self-JOIN: 동일 고객의 거래를 국내/해외로 분리 비교
--   - DATE() + BETWEEN + INTERVAL: 날짜 구간 비교
--   - IN 연산자: 도시 목록 필터
--
-- [FDS Insight]
--   이 패턴은 '불가능 여행(Impossible Travel)'의 확장 버전이다.
--   국내+해외 4일 이내 거래는 단순 여행으로도 가능하지만,
--   fraud율이 75%에 달하므로 다른 Rule과 OR 결합 시 재현율 향상에 기여한다.
--   단, 단독 Rule로 사용 시 오탐 발생 위험이 있어 보조 조건으로 활용 권장.
-- ============================================================

-- 도시 목록 확인
SELECT DISTINCT city FROM fraud_transactions;

-- 4일 이내 국내+해외 동시 사용 탐지
SELECT
    fd1.txn_date                AS 국내_거래일시,
    fd2.txn_date                AS 해외_거래일시,
    fd1.customer_id,
    fd1.amount                  AS 국내_금액,
    fd2.amount                  AS 해외_금액,
    fd1.city                    AS 국내_도시,
    fd2.city                    AS 해외_도시,
    fd1.is_fraud
FROM fraud_transactions fd1
JOIN fraud_transactions fd2
    ON  fd1.customer_id = fd2.customer_id
WHERE fd2.city IN ('미국', '중국', '유럽')
  AND fd1.city IN ('부산', '인천', '대구', '제주', '대전', '광주', '수원', '서울')
  AND DATE(fd2.txn_date) BETWEEN DATE(fd1.txn_date)
                              AND DATE(fd1.txn_date) + INTERVAL '4 day'
  AND DATE(fd2.txn_date) != DATE(fd1.txn_date)
ORDER BY fd1.customer_id, fd1.txn_date;
