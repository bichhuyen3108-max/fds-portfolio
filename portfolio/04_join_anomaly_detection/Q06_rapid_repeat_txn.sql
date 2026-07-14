-- ============================================================
-- Q06. 1시간 내 반복 거래 탐지 (카드복제 패턴)
-- ============================================================
-- [비즈니스 문제]
--   정상 고객이 1시간 안에 동일 고객 명의로 2건 이상 거래를 발생시키는 경우는
--   드물다. 이 패턴은 카드 복제(Card Cloning) 또는 계정 공유 사기의
--   대표적 시그널이다.
--   → Self-JOIN으로 동일 고객의 거래 쌍을 비교하여 단기 반복 거래를 탐지한다.
--
-- [변경 이력]
--   이전 버전: HAVING count >= 3 (3건 이상)
--   현재 버전: HAVING count >= 2 (2건 이상) — 더 넓은 범위 탐지
--   추가: string_agg로 해당 창(window) 내 거래 목록을 함께 출력
--         → 운영팀이 직접 거래 내역을 확인할 수 있어 실무 활용도 향상
--
-- [사용 기술]
--   - Self-JOIN: 동일 테이블을 t1, t2로 두 번 참조
--   - INTERVAL: 시간 구간 조건 설정
--   - string_agg: 창 내 거래 목록을 하나의 문자열로 집계
--   - HAVING: 집계 후 조건 필터링
--
-- [FDS Insight]
--   1시간 내 2건 이상 반복 거래는 카드 복제 의심 신호다.
--   단, 정상 고객도 빠른 연속 구매를 할 수 있으므로
--   다른 조건(새벽 시간, 고액, 타지역)과 AND 결합하면 정탐률이 높아진다.
-- ============================================================

-- 각 열의 데이터 유형 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'fraud_transactions';

-- 1시간 내 2건 이상 거래 탐지
SELECT
    t1.customer_id,
    t1.txn_id,
    t1.txn_date                                                         AS 기준_거래시각,
    string_agg(t2.txn_id || ' (' || t2.txn_date::text || ')', ', ')    AS 창내_거래목록,
    COUNT(t2.txn_id)                                                    AS 창내_거래수
FROM fraud_transactions t1
JOIN fraud_transactions t2
    ON  t1.customer_id = t2.customer_id
    AND t2.txn_date   >= t1.txn_date
    AND t2.txn_date   <= t1.txn_date + INTERVAL '1 hour'
GROUP BY t1.customer_id, t1.txn_id, t1.txn_date
HAVING COUNT(t2.txn_id) >= 2
ORDER BY 창내_거래수 DESC;
