-- =============================================
-- FRAUD FDS 실전 연습 문제집
-- 사고FDS팀 대비
-- =============================================

-- ================================================================
-- [LEVEL 1] 기본 조회 — 데이터 파악
-- ================================================================

-- Q1. 전체 거래 중 fraud 건수와 비율을 구하세요.
select
	count(*) as 총거래건수,
	count(case when is_fraud = true then 1 end) as fraud_건수,
	round(100.0*count(case when is_fraud = true then 1 end)/count(*),2) as fraud_percent
from fraud_transactions ;

-- cách 2 dùng hàm FILTER
select
	count(*) as 총거래건수,
	count(*) filter (where is_fraud =TRue) as 	fraud_건수,
	round(100.0* (count(*) filter (where is_fraud = true))/count(*),2) as fraud_percent
from fraud_transactions ;

-- Q2. fraud_type별 건수와 평균 금액을 구하세요.
select 
	fraud_type ,
	count(*) as fraud_type별_건수,
 	round(avg(amount),2) as avg_amount 
from fraud_transactions 
where fraud_type is not NULL
group by fraud_type 
order by round(avg(amount),2);

-- Q3. 채널(channel)별 fraud 발생 건수를 구하세요.
select channel,
		count(*) filter(where is_fraud is true) as fraud_건수
from fraud_transactions 
group by channel;


-- Q4. 새벽 시간대(00~05시) 거래를 조회하고
--     정상 vs fraud 건수를 비교하세요.
select 
	count(*) as 총거래,
	count(*) filter (where is_fraud is true ) as fraud_건수,
	count(*) filter (where is_fraud is not true) as 정상_건수
from fraud_transactions
where extract (hour from txn_date) between 0 and 5;

-- Q5. 고객 1명당 평균 거래 건수와 평균 거래 금액을 구하세요.
select round(avg(거래_건수),2) as 고객_1명당_평균_거래_건수,
       round(avg(평균_거래_금액),2) as 고객_1명당_평균_거래_금액
from (select customer_id ,
	count(txn_id) as 거래_건수,
	round(avg(amount),2) as 평균_거래_금액
from fraud_transactions
group by customer_id) as summary;
 -- cách 2 với CTE
with customer_avg as (
	select customer_id ,
		count(txn_id) as 거래_건수,
		round(avg(amount),2) as 평균_거래_금액
	from fraud_transactions
	group by customer_id
)
select round(avg(거래_건수),2) as 고객_1명당_평균_거래_건수,
       round(avg(평균_거래_금액),2) as 고객_1명당_평균_거래_금액
from customer_avg;

-- ================================================================
-- [LEVEL 2] 이상거래 탐지 — Rule 기반
-- ================================================================
-- Q6. 동일 고객이 1시간 내에 2건 이상 거래한 경우를 찾으세요.
--     (단기 반복 거래 = 카드복제 패턴)

--각 열의 데이터 유형을 빠르게 확인하는 방법
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'fraud_transactions';
--
SELECT t1.customer_id, t1.txn_id, t1.txn_date as date_before, 
		string_agg(t2.txn_id || ' (' || t2.txn_date::text || ')', ', ') AS txns_in_window,
		count(t2.txn_id) AS count_txn
FROM fraud_transactions t1
JOIN fraud_transactions t2
    ON t1.customer_id = t2.customer_id
    AND t2.txn_date >= t1.txn_date
    AND t2.txn_date <= t1.txn_date + interval '1 hour'
GROUP BY t1.customer_id, t1.txn_id, t1.txn_date
HAVING count(t2.txn_id) >= 2;	

-- Q7. 고객 평균 거래금액의 5배 이상인 거래를 찾으세요.
--     (이상 고액 거래 탐지)
with customer_avg_amount as(
	select customer_id , txn_id, amount,
		round(avg(amount) over(partition by customer_id ),2) as customer_avg
	from fraud_transactions 
)
select customer_id, txn_id, customer_avg, amount
from customer_avg_amount
where amount > 5*customer_avg

-- Q8. 거주 도시와 다른 도시에서 발생한 거래를 찾으세요.
--     (타지역 이상거래)
select c.customer_id , c.city , ft.city as city_transaction, ft.is_fraud , ft.amount 
from fraud_transactions ft
join customers c on ft.customer_id = c.customer_id 
where c.city <> ft.city 
order by ft.amount desc;

-- Q9. 해외 거래(city IN '미국','중국','유럽') 고객 중
--     4일 이내 국내 거래도 있는 고객을 찾으세요.
--     (해외+국내 동시 사용 = 카드복제 의심)
select distinct city
from fraud_transactions ;


select fd1.txn_date as 국내날자, fd2.txn_date as 해외날자,
	fd1.customer_id, fd1.amount as 국내거래_금액, fd2.amount as 해외거래_금액,
	fd1.city as 국내, fd2.city as 해외거래, fd1.is_fraud
from fraud_transactions fd1
join fraud_transactions fd2 	
	on fd1.customer_id =fd2.customer_id 
where fd2.city in ('미국','중국','유럽') 
	and fd1.city in ('부산','인천','대구','제주','대전','광주','수원','서울')
	and (DATE(fd2.txn_date) between DATE(fd1.txn_date) and  DATE(fd1.txn_date) + interval '4 day')
	and DATE(fd2.txn_date) != DATE(fd1.txn_date)

-- Q10. 가입 후 7일 이내에 50만원 이상 거래한 신규 고객을 찾으세요.
--      (입회사기 패턴)


select c.customer_id , c.join_date , ft.txn_date , ft.amount
from customers c
join fraud_transactions ft on c.customer_id = ft.customer_id 
where date(ft.txn_date ) between c.join_date and (c.join_date + interval '7 day')
	and ft.amount >= 500000;

-- ================================================================
-- [LEVEL 3] FDS Rule 성능 분석
-- ================================================================

-- Q11. Rule별 정탐(True Positive)과 오탐(False Positive) 수를 구하세요.
--      정탐 = is_fraud=TRUE인 거래를 Rule이 잡은 경우
--      오탐 = is_fraud=FALSE인데 Rule 조건에 걸린 경우
-- (Q7 Rule 기준: 평균의 5배 이상 거래)
with customer_avg_amount as(
	select txn_id, customer_id, amount, is_fraud,
		round(avg(amount) over(partition by customer_id),2) as avg_amount
	from fraud_transactions 	
),
avg_more_than as(
	select txn_id, customer_id, amount, avg_amount, is_fraud
	from customer_avg_amount
	where amount > 5* avg_amount 
)

select
	count(*) as 총수,
	count(*) filter(where is_fraud = true) as 정탐_수 ,
	count(*) filter(where is_fraud is not true) as 오탐_수,
	round(100.0* count(*) filter(where is_fraud = true)/ count(*),2) as 정탐률, 
	round(100.0 * count(*) filter(where is_fraud = true)/ 
		(select count(*) from fraud_transactions where is_fraud = true),2) as 재현률,
	round(100.0*count(*) filter(where is_fraud is not true)/
		(select count(*) from fraud_transactions where is_fraud = false),2) as 오탐률
from avg_more_than;



-- Q12. 월별 fraud 발생 추이를 구하세요.
--      (월별 fraud 건수, fraud율 변화)
with txn_date_month as(
	select date_trunc('month', txn_date) as txn_month, *
	from fraud_transactions
)
select  txn_month,
	count(*) as 총거래,
	count(*) filter(where is_fraud = true) as fraud_건수_month,
	round(100.0* count(*) filter(where is_fraud = true)/ count(*),2) as fraud율 
from txn_date_month
group by txn_month
order by fraud율 desc

-- Q13. fraud_type별로 주로 발생하는 시간대(오전/오후/새벽)를 분석하세요.
select case
			when extract(hour from txn_date) between 0 and 5 then '새벽' 
			when extract(hour from txn_date) between 6 and 12 then '오전'
			else '오후' 
		end as 시간대,
		fraud_type,
		count(*) as 총거래
from fraud_transactions
where fraud_type is not null
group by 시간대, fraud_type
order by fraud_type, 총거래 desc

-- Q14. 신용등급(credit_grade)별 fraud 발생률을 구하세요.
--      어떤 등급이 fraud에 가장 취약한지 확인하세요.

select 
	c.credit_grade,
	count(*) as total_fraud,
	count(*) filter ( where ft.is_fraud is true) as count_fraud,
	round(100.0* count(*) filter ( where ft.is_fraud is true)/
				count(*),2) as fraud_발생률
from fraud_transactions ft 
join customers c on ft.customer_id = c.customer_id 
group by c.credit_grade
order by round(100.0* (count(*) filter ( where ft.is_fraud is true)/
		count(*)),2) desc
		
-- ================================================================
-- [변수 상관관계 분석] Rule 설계 전 근거 분석
-- ================================================================

-- [분석1] 시간대별 fraud율 → Rule1 새벽 조건 근거

select 
	extract(hour from txn_date) as 시간대,
	count(*) as 총거래,
	count(*) filter ( where is_fraud = true) as fraud_건수,
	round(100.0* count(*) filter ( where is_fraud = true)/count(*),2) as fraud율
from fraud_transactions
group by 시간대
order by fraud율 desc;

-- [분석2] 금액 구간별 fraud율 → rule2 임계값 30만원 근거
select 
	case 
		when amount < 100000 then '10만 미만'
		when amount < 300000 then '10~30만원'
		when amount < 500000 then '30~50만원'
		when amount < 1000000 then '50~100만원'
		else '100만원 이상'
	end as 금액구간, 
	count(*) as 총거래,
	count(*) filter (where is_fraud = true) as fraud_건수,
	round(100.0* count(*) filter ( where is_fraud = true)/count(*),2) as fraud율
from fraud_transactions
group by 금액구간
order by fraud율 desc;

--임계값을 바꿔가면서 정탐률/재현율 변화 측정
--→ 최적 균형점 찾기!
SELECT
    '30만원 이상' AS 임계값,
    COUNT(*) AS 총탐지,
    COUNT(*) FILTER (WHERE is_fraud = TRUE) AS 정탐,
    COUNT(*) FILTER (WHERE is_fraud = FALSE) AS 오탐,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / COUNT(*), 2) AS 정탐률,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions 
             WHERE is_fraud = TRUE), 2) AS 재현율
FROM fraud_transactions
WHERE amount >= 300000

UNION ALL

SELECT
    '50만원 이상' AS 임계값,
    COUNT(*) AS 총탐지,
    COUNT(*) FILTER (WHERE is_fraud = TRUE) AS 정탐,
    COUNT(*) FILTER (WHERE is_fraud = FALSE) AS 오탐,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / COUNT(*), 2) AS 정탐률,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions 
             WHERE is_fraud = TRUE), 2) AS 재현율
FROM fraud_transactions
WHERE amount >= 500000

UNION ALL

SELECT
    '100만원 이상' AS 임계값,
    COUNT(*) AS 총탐지,
    COUNT(*) FILTER (WHERE is_fraud = TRUE) AS 정탐,
    COUNT(*) FILTER (WHERE is_fraud = FALSE) AS 오탐,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / COUNT(*), 2) AS 정탐률,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions 
             WHERE is_fraud = TRUE), 2) AS 재현율
FROM fraud_transactions
WHERE amount >= 1000000

ORDER BY 재현율 DESC;
-- [결과 해석]
-- 30만원: 정탐률 78.91% / 재현율 82.2%  / 오탐 58건
-- 50만원: 정탐률 98.88% / 재현율 67.05% / 오탐  2건
-- 100만원: 정탐률 100%  / 재현율 56.06% / 오탐  0건

-- [비즈니스 모델별 임계값 선택 기준]
--
-- 카드사 (현대카드, 한패스):
--   주요 수익 = 카드 수수료
--   → 정상 고객 거래 차단 = 수익 손실 + 고객 이탈
--   → 오탐 최소화 우선
--   → >=50만원 또는 >=100만원 선택
--
-- 핀테크 / 간편결제 (토스, 카카오페이):
--   신뢰가 핵심 비즈니스
--   → fraud 1건이 브랜드 이미지 타격
--   → 재현율 우선, 오탐 어느 정도 감수
--   → >=30만원 선택
--
-- 보험사 / 대출:
--   고액 거래 위주
--   → 고액 fraud 놓치는 손실 > 소액 오탐 손실
--   → 재현율 우선
--   → >=30만원 선택
--
-- [최종 선택: 현대카드/한패스 기준 >=50만원]
--   정탐률 98.88% + 재현율 67.05% + 오탐 2건
--   → 오탐 최소화하면서 재현율도 충분히 확보

-- [분석3] 채널별 fraud율 → rule3 ATM 제외 조건 근거
select
	channel,
	count(*) as 총거래,
	count(*) filter (where is_fraud = true) as fraud_건수,
	round(100.0* count(*) filter ( where is_fraud = true)/count(*),2) as fraud율
from fraud_transactions 
group by channel
order by fraud율 desc;

--  채널 단독 Rule 성능 테스트
select 
	'온라인만' as 채널조건,
	count(*) as 총탐지,
	count(*) filter(where is_fraud = true) as 정탐,
	count(*) filter(where is_fraud is not true) as 오탐,
	round(100.0* count(*) filter(where is_fraud = true)/ count(*),2) as 정탐률,
	round(100.0* count(*) filter(where is_fraud = true)/
	(select  count(*) from fraud_transactions where is_fraud = true),2) as 재현률
from fraud_transactions	
where channel = '온라인'

union all

select 
	'온라인 + 카드' as 채널조건,
	count(*) as 총탐지,
	count(*) filter(where is_fraud = true) as 정탐,
	count(*) filter(where is_fraud is not true) as 오탐,
	round(100.0* count(*) filter(where is_fraud = true)/ count(*),2) as 정탐률,
	round(100.0* count(*) filter(where is_fraud = true)/
	(select  count(*) from fraud_transactions where is_fraud = true),2) as 재현률
from fraud_transactions	
where channel in ('온라인','카드')

union all

select 
	'온라인 + 카드 + 모바일' as 채널조건,
	count(*) as 총탐지,
	count(*) filter(where is_fraud = true) as 정탐,
	count(*) filter(where is_fraud is not true) as 오탐,
	round(100.0* count(*) filter(where is_fraud = true)/ count(*),2) as 정탐률,
	round(100.0* count(*) filter(where is_fraud = true)/
	(select  count(*) from fraud_transactions where is_fraud = true),2) as 재현률
from fraud_transactions	
where channel in ('온라인','카드','모바일')

order by 재현률 desc;

-- ================================================================
-- [채널별 단독 분석] channel이 Rule 조건으로 적합한지 검증
-- ================================================================

-- 채널별 fraud율 분석 결과:
-- 온라인: 22.63% / 카드: 15.17% / 모바일: 12.09% / ATM: 0%

-- 채널 단독 Rule 성능 테스트:
-- 온라인만:           정탐률 22.63% / 재현율 46.21% / 오탐 417건
-- 온라인+카드:        정탐률 19.04% / 재현율 75%    / 오탐 842건
-- 온라인+카드+모바일: 정탐률 16.65% / 재현율 100%   / 오탐 1322건

-- [결론]
-- 채널 단독으로는 정탐률이 16~22%로 너무 낮고
-- 오탐이 417~1322건으로 과도하게 발생
-- → 채널 단독 Rule로는 부적합!
-- → 단독 Rule이 아닌 기존 Rule1~4와 함께
--    AND 조건으로 결합해 보조 조건으로 활용
-- → Q17 최종 Rule에서 성능 검증 후 결론 도출
-- ================================================================

-- [분석4] 타지역 거래 fraud율 → Rule4 타지역 조건 근거
select
	case when ft.city != c.city then '티지역' else '거주지' end as 타지역_조건,
	count(*) as 총거래,
	count(*) filter (where ft.is_fraud = true) as fraud_건수,
	round(100.0* count(*) filter ( where ft.is_fraud = true)/count(*),2) as fraud율
from fraud_transactions ft
join customers c on ft.customer_id = c.customer_id
group by 타지역_조건
order by fraud율 desc;

select 
	'타지역' as 지역조건,
	count(*) as 총탐지,
	count(*) filter(where is_fraud = true) as 정탐,
	count(*) filter(where is_fraud is not true) as 오탐,
	round(100.0* count(*) filter(where is_fraud = true)/ count(*),2) as 정탐률,
	round(100.0* count(*) filter(where is_fraud = true)/
	(select  count(*) from fraud_transactions where is_fraud = true),2) as 재현률
from fraud_transactions ft
join customers c on ft.customer_id = c.customer_id
where ft.city != c.city
order by 재현률 desc;
-- ================================================================
-- [분석4] 타지역 거래 fraud율 분석 → Rule4 타지역 조건 근거
-- ================================================================

-- 분석 결과:
-- 타지역 거래: 총 193건 중 fraud 193건 → fraud율 100%
-- 거주지 거래: 총 1807건 중 fraud 71건 → fraud율 3.93%

-- 타지역 단독 Rule 성능:
-- 총탐지: 193건 / 정탐: 193건 / 오탐: 0건
-- 정탐률: 100% / 재현율: 73.11%

-- [결론]
-- 타지역 거래는 정탐률 100%, 오탐 0건으로
-- 가장 강력하고 정확한 fraud 신호!
-- → 단독으로도 완벽한 Rule로 작동
-- → Rule2 타지역 조건으로 확정 

-- [비즈니스 해석]
-- 고객이 거주지가 아닌 타지역에서 거래 발생
-- → 카드 도난 또는 복제 가능성 높음
-- → 즉시 모니터링 및 추가 인증 필요
-- ================================================================

-- [분석5] Fraud vs 정상 평균금액 비교 → rule5 평균 3배 임계값 근거
SELECT
    is_fraud,
    ROUND(AVG(amount), 0)  AS 평균금액,
    ROUND(MIN(amount), 0)  AS 최소금액,
    ROUND(MAX(amount), 0)  AS 최대금액,
    COUNT(*)               AS 건수
FROM fraud_transactions
GROUP BY is_fraud;

-- 2배, 3배, 4배, 5배 모두 테스트!
WITH customer_avg AS (
    SELECT customer_id, txn_id, amount, is_fraud,
        AVG(amount) OVER (PARTITION BY customer_id) AS avg_amount
    FROM fraud_transactions
)
SELECT '2배 이상' AS 임계값,
    COUNT(*) AS 총탐지,
    COUNT(*) FILTER (WHERE is_fraud = TRUE) AS 정탐,
    COUNT(*) FILTER (WHERE is_fraud = FALSE) AS 오탐,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / COUNT(*), 2) AS 정탐률,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions
             WHERE is_fraud = TRUE), 2) AS 재현율
FROM customer_avg
WHERE amount >= 2 * avg_amount

UNION ALL

SELECT '3배 이상',
    COUNT(*), 
    COUNT(*) FILTER (WHERE is_fraud = TRUE),
    COUNT(*) FILTER (WHERE is_fraud = FALSE),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions
             WHERE is_fraud = TRUE), 2)
FROM customer_avg
WHERE amount >= 3 * avg_amount

UNION ALL

SELECT '4배 이상',
    COUNT(*),
    COUNT(*) FILTER (WHERE is_fraud = TRUE),
    COUNT(*) FILTER (WHERE is_fraud = FALSE),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions
             WHERE is_fraud = TRUE), 2)
FROM customer_avg
WHERE amount >= 4 * avg_amount

UNION ALL

SELECT '5배 이상',
    COUNT(*),
    COUNT(*) FILTER (WHERE is_fraud = TRUE),
    COUNT(*) FILTER (WHERE is_fraud = FALSE),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / COUNT(*), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = TRUE)
          / (SELECT COUNT(*) FROM fraud_transactions
             WHERE is_fraud = TRUE), 2)
FROM customer_avg
WHERE amount >= 5 * avg_amount

ORDER BY 재현율 DESC;

-- ================================================================
-- [분석5] Fraud vs 정상 평균금액 비교 → 평균 배수 임계값 근거
-- ================================================================

-- Fraud vs 정상 평균금액 비교:
-- 정상 평균금액: 151,533원 / 최소: 10,000원 / 최대: 959,485원
-- fraud 평균금액: 1,463,485원 / 최소: 50,000원 / 최대: 5,000,000원
-- → fraud가 정상보다 평균 약 10배 높음
-- → 단, 정상 최대(96만원) > fraud 최소(5만원) 겹치는 구간 존재
-- → 절대 금액이 아닌 "개인 평균 대비 배율"로 임계값 설정!

-- 배수별 임계값 성능 테스트:
-- 2배 이상: 총탐지 190건 / 정탐 151건 / 오탐 39건
--           정탐률 79.47% / 재현율 57.2%
-- 3배 이상: 총탐지  87건 / 정탐  87건 / 오탐  0건
--           정탐률  100% / 재현율 32.95%
-- 4배 이상: 총탐지  38건 / 정탐  38건 / 오탐  0건
--           정탐률  100% / 재현율 14.39%
-- 5배 이상: 총탐지  14건 / 정탐  14건 / 오탐  0건
--           정탐률  100% / 재현율  5.3%

-- [비즈니스별 임계값 선택 기준]
-- 재현율 우선 (토스, 카카오페이 등):
--   → 2배 선택: 재현율 57.2%로 fraud 많이 탐지
--   → 단, 오탐 39건 발생 감수

-- 정탐률/오탐 최소화 우선 (현대카드, 한패스 등):
--   → 3배 선택: 정탐률 100% + 오탐 0건
--   → 고객 불편 없음 + 수익 기회 손실 없음

-- [최종 선택: 현대카드/한패스 기준 → 3배]
-- 정탐률 100% + 오탐 0건 유지하면서
-- 전체 Rule OR 조합으로 재현율 보완
-- ================================================================

-- Q15. [종합] AND 복합조건 고위험 거래 탐지
-- 변수 분석 결과 반영:
-- 시간대: 1~5시 (fraud율 18~28%로 최고)
-- 금액: 50만원 이상 (정탐률 98.88% + 오탐 2건)
-- 채널: ATM 제외 (ATM fraud율 0%)
-- 타지역 이상거래 (거주 도시와 다른 도시 )
-- 평균배수: 3배 (정탐률 100% + 오탐 0건)
--		다음에 이 Rule별 정탐률과 재현률과 오탐률을 구하세요.
with fraud_transactions_summary as (
	select ft.*,
		extract(hour from ft.txn_date) as txn_hour,
		c.city as 거주도시,
		round(avg(ft.amount) over(partition by ft.customer_id),2) as avg_amount
	from fraud_transactions ft
	join customers c  on ft.customer_id = c.customer_id
),
rule2 as(
	select *
	from fraud_transactions_summary
	where (txn_hour between 1 and 5) and 
		amount >= 500000 and 
		channel != 'ATM' and
		amount >= 3*avg_amount and
		city != 거주도시	
	order by amount desc
)	
select 
	count(*) as 총탐지_수,
	count(*) filter(where is_fraud = true) as 정탐_수,
	count(*) filter(where is_fraud is not true) as 오탐_수,
	round(100.0 * count(*) filter(where is_fraud = true)/ count(*),2) as 정탐률,
	round(100.0 * count(*) filter(where is_fraud = true)/ 
	(select count(*) from fraud_transactions where is_fraud = true) ,2) as 재현률,
	round(100.0 * count(*) filter(where is_fraud  is not true)/ 
	(select count(*) from fraud_transactions where is_fraud is not true) ,2) as 오탐률
from rule2	

-- ================================================================
-- [Q15 결과 분석 및 Q16 개선 방향]
-- ================================================================

-- Q15 결과:
-- 총탐지: 32건 / 정탐: 432건 / 오탐: 0건
-- 정탐률: 100% / 재현율: 12.12% / 오탐률: 0%

-- [한계점 발견]
-- 정탐률 100%, 오탐률 0% → 정확도는 완벽
-- 하지만 재현율 12.12% → 265건 중 32건만 탐지
-- → 233건의 fraud를 놓치고 있음!

-- [원인 분석]
-- AND 조건 4개를 모두 만족해야 탐지
-- → 조건이 너무 엄격해서 범위가 좁음
-- → 새벽 + 고액 + 특정채널 + 평균3배
--    동시에 만족하는 거래가 적음

-- [개선 방향 → Q16]
-- AND → OR로 전환
-- 각 fraud 유형별 Rule을 따로 설계
-- 1개 이상 만족하면 탐지
-- → 재현율 대폭 향상 기대!
-- ================================================================

-- Q16. [종합] 다음 중 1 개 이상 만족하는 고위험 거래를 탐지하세요:
-- 변수 분석 결과 반영:
-- 시간대: 1~5시 (fraud율 18~28%로 최고)
-- 금액: 50만원 이상 (정탐률 98.88% + 오탐 2건)
-- 채널: ATM 제외 (ATM fraud율 0%)
-- 타지역 이상거래 (거주 도시와 다른 도시 )
-- 평균배수: 3배 (정탐률 100% + 오탐 0건)
--   -> 다음에 이 Rule별 정탐률과 재현률과 오탐률을 구하세요.
with rule1 as(
	select txn_id, customer_id, txn_date, 
		extract(hour from txn_date) as txn_hour,
		amount, is_fraud 
	from fraud_transactions 
	where extract(hour from txn_date) between 1 and 5	
),
rule2 as (
	select 	txn_id, customer_id, txn_date,amount, is_fraud 
	from fraud_transactions
	where amount >=500000
),
rule3 as(
	select txn_id, customer_id, txn_date,amount,channel, is_fraud 
	from fraud_transactions
	where channel != 'ATM'
), 
rule4 as(
	select ft.txn_id, ft.customer_id, ft.txn_date, ft.amount, ft.is_fraud, 
		c.city as 거주도시, ft.city as 거래도시
	from fraud_transactions ft
	join customers c on c.customer_id = ft.customer_id 
	where ft.city != c.city
),
rule5 as (
	select txn_id, customer_id, txn_date,amount, is_fraud, avg_amount
	from(select txn_id, customer_id, txn_date,amount, is_fraud,
			round(avg(amount) over(partition by customer_id),2) as avg_amount
		from fraud_transactions ft)
	where amount >= 3*avg_amount
),
result as (
	select *
	from (select ft.*,
			(case when r1.txn_id is not null then 1 else 0 end +
			case when r2.txn_id is not null then 1 else 0 end +
			case when r3.txn_id is not null then 1 else 0 end +
			case when r4.txn_id is not null then 1 else 0 end +
			case when r5.txn_id is not null then 1 else 0 end ) as count_rule
		from fraud_transactions ft 
		left join rule1  r1 on ft.txn_id = r1.txn_id
		left join rule2  r2 on ft.txn_id = r2.txn_id
		left join rule3  r3 on ft.txn_id = r3.txn_id
		left join rule4  r4 on ft.txn_id = r4.txn_id
		left join rule5  r5 on ft.txn_id = r5.txn_id)
	where count_rule >=1
)
select
	count(*) as 총탐수,
	count(*) filter( where is_fraud = true) as 정탐,
	count(*) filter( where is_fraud is not true) as 오탐,
	round(100.0* count(*) filter( where is_fraud = true)/count(*),2) as 정탐율,
	round(100.0* count(*) filter( where is_fraud = true)/
		(select count(*) from fraud_transactions where is_fraud = true) ,2) as 재현율,
	round(100.0* count(*) filter( where is_fraud is not true)/
		(select count(*) from fraud_transactions where is_fraud = true) ,2) as 오탐율
from result
-- ================================================================
-- [Q16 결과 분석]
-- ================================================================
-- 결과:
-- 총탐지: 1,676건 / 정탐: 264건 / 오탐: 1,412건
-- 정탐률: 15.75% / 재현율: 100% / 오탐률: 534.85%

-- [발견]
-- 재현율 100% → 모든 fraud 탐지 성공! ✅
-- 하지만 정탐률 15.75% → 잡은 것 중 84.25%가 정상 거래!
-- 오탐률 534.85% → 정상 거래를 너무 많이 잡음 ❌

-- [원인 분석]
-- OR 조건이 너무 넓음:
-- "ATM 제외" 조건 → 정상 거래 대부분 포함
-- "50만원 이상" 조건 → 정상 고액 거래도 포함
-- 각 조건이 단독으로는 fraud 식별력이 낮음

-- [결론]
-- Q15 (AND): 정탐률 100% / 재현율 낮음 → 너무 엄격
-- Q16 (OR):  재현율 100% / 정탐률 낮음 → 너무 느슨
-- → 두 극단의 균형점이 필요!

-- [개선 방향 → Q17]
-- 단순 OR이 아닌
-- "fraud 유형별 복합 조건"을 OR로 연결!
-- 예: 보이스피싱 = 새벽 AND 모바일 AND 50만원
--     타지역     = 거주지 외 도시
--     입회사기   = 가입 7일 내 고액
-- → 각 Rule이 단독으로도 의미있는 조건!
-- → Q17에서 재현율과 정탐률 균형 달성!
-- ================================================================

-- ================================================================
-- [입회사기 Rule 검증 및 제외 근거]
-- ================================================================

-- 검증 query: 가입 후 일수별 fraud율 분석
 select 
 	date(ft.txn_date) - date(c.join_date ) as 가입후일수,
 	count(*) as 총탐수,
	count(*) filter( where is_fraud = true) as 정탐,
	round(100.0* count(*) filter( where is_fraud = true)/count(*),2) as fraud율
 from fraud_transactions ft
 join customers c on ft.customer_id = c.customer_id 
 where (date(ft.txn_date) - date(c.join_date )) <= 10
	and ft.txn_date >= c.join_date
group by 가입후일수
order by 가입후일수 ;
 
-- [검증 결과]
-- 가입 후 0~10일 fraud율: 0% ~ 25% 불규칙 분포
-- 전체 평균 fraud율(12%)과 비교해
-- 특정 기간에 집중되는 패턴 없음
-- 또한 일별 거래 건수가 2~87건으로 적어
-- 통계적 신뢰도가 낮음

-- [제외 근거]
-- 1. fraud율이 특정 기간에 집중되지 않음
-- 2. 거래 건수 부족으로 통계 신뢰도 낮음
-- 3. 데이터로 증명되지 않은 Rule은 포함하지 않음
-- → 데이터 기반 의사결정 원칙

-- [실무 적용 방법]
-- 실제 데이터에서는:
-- 가입 0~3일: fraud율 높음 → 집중 모니터링
-- 가입 4~7일: fraud율 중간 → 일반 모니터링
-- 가입 8일~: fraud율 낮음 → 정상 패턴
-- → 충분한 거래 건수 확보 후 임계값 도출

-- [결론]
-- 입회사기 Rule은 현재 데이터셋에서 제외
-- 실무 데이터 확보 시 추가 검토 예정 
-- ================================================================

-- ================================================================
-- [해외이상 Rule 검증 결론 → Q17 방향 설정]
-- ================================================================

select 
	abs(date(ft1.txn_date)  - date(ft2.txn_date)) as 거래일수,
	count(*) as 총탐수,
	count(*) filter( where ft1.is_fraud = true) as 정탐,
	round(100.0* count(*) filter( where ft1.is_fraud = true)/count(*),2) as fraud율		
from fraud_transactions ft1
join fraud_transactions ft2 on ft1.customer_id = ft2.customer_id
where date(ft1.txn_date) != date(ft2.txn_date)
	and ft1.city in ('부산','인천','대구','제주','대전','광주','수원','서울' )
	and ft2.city in ('미국','중국','유럽')
	and abs(date(ft1.txn_date)  - date(ft2.txn_date)) <=7
group by 거래일수
order by 거래일수;
-- ================================================================
-- [검증 결과]
-- 4일째 fraud율 75%로 가장 높음
-- 단, 총탐수 4건으로 통계적 신뢰도 낮음

-- [Q17 방향 설정]
-- Q17-A: 해외이상 제외 → 오탐 최소화 우선
-- Q17-B: 해외이상 포함 → 재현율 향상 우선
-- ================================================================

-- Q17-A. [종합] 다음 중 1 개 이상 만족하는 고위험 거래를 탐지하세요:
--      1) 보이스피싱 Rule:새벽 1시-5시 + 모바일 + 50만원 이상
-- 		2) 타지역 이상거래 (거주 도시와 다른 도시 고액 거래 50만원 이상)
--      3) 평균 3배 이상 거래 이력 있음
--		다음에 이 Rule별 정탐률과 재현률과 오탐률을 구하세요.
with rule1 as(
	select txn_id, customer_id, txn_date,
		extract(hour from txn_date) as txn_hour,
		amount, channel, is_fraud	
	from fraud_transactions  
	where extract(hour from txn_date) between 1 and 5
		and channel = '모바일'
		and amount >= 500000
),
rule2 as(
	select ft.txn_id, ft.customer_id , ft.txn_date, ft.amount, ft.is_fraud,
			 ft.city as 거래도시, c.city as 거주도시
	from fraud_transactions ft 
	join customers c on ft.customer_id = c.customer_id 
	where ft.city != c.city and amount >= 500000
),
rule3 as(
	select txn_id, customer_id, txn_date, amount, channel, is_fraud
	from (select *, avg(amount) over(partition by customer_id) as avg_amount
		from fraud_transactions ) as summary
	where amount >= 3* avg_amount
),
result as(
	select *
	from (
		select ft.txn_id, ft.is_fraud,	
			(case when r1.txn_id is not null then 1 else 0 end+
			case when r2.txn_id is not null then 1 else 0 end +
			case when r3.txn_id is not null then 1 else 0 end) as count_rule
		from fraud_transactions ft
		left join rule1 r1 on r1.txn_id = ft.txn_id
		left join rule2 r2 on r2.txn_id = ft.txn_id
		left join rule3 r3 on r3.txn_id = ft.txn_id) as summary
	where count_rule >=1	
)
select
	count(*) as 총탐수,
	count(*) filter( where is_fraud = true) as 정탐,
	count(*) filter( where is_fraud is not true) as 오탐,
	round(100.0* count(*) filter( where is_fraud = true)/count(*),2) as 정탐율,
	round(100.0* count(*) filter( where is_fraud = true)/
		(select count(*) from fraud_transactions where is_fraud = true) ,2) as 재현율,
	round(100.0* count(*) filter( where is_fraud is not true)/
		(select count(*) from fraud_transactions where is_fraud is not true) ,2) as 오탐율
from result
-- Q17-B. [종합] 다음 중 1 개 이상 만족하는 고위험 거래를 탐지하세요:
--      1) 보이스피싱 Rule:새벽 1시-5시 + 모바일 + 50만원 이상
-- 		2) 타지역 이상거래 (거주 도시와 다른 도시 고액 거래 50만원 이상)
-- 		3) 해외이상 Rule:4일 이내 국내+해외 동시 사용
--      4) 평균 3배 이상 거래 이력 있음
--		다음에 이 Rule별 정탐률과 재현률과 오탐률을 구하세요.
with rule1 as(
	select txn_id, customer_id, txn_date,
		extract(hour from txn_date) as txn_hour,
		amount, channel, is_fraud	
	from fraud_transactions  
	where extract(hour from txn_date) between 1 and 5
		and channel = '모바일'
		and amount >= 500000
),
rule2 as(
	select ft.txn_id, ft.customer_id , ft.txn_date, ft.amount, ft.is_fraud,
			 ft.city as 거래도시, c.city as 거주도시
	from fraud_transactions ft 
	join customers c on ft.customer_id = c.customer_id 
	where ft.city != c.city and amount >= 500000
),
rule3 as(
	select ft1.txn_id, ft1.customer_id , ft1.txn_date, ft1.amount, ft1.is_fraud,
		ft1.city as 국내거래, ft2.city as 해외거래
	from fraud_transactions ft1
	join fraud_transactions ft2 on ft1.customer_id = ft2.customer_id
	where date(ft2.txn_date) between date(ft1.txn_date) and  (date(ft1.txn_date) + interval '4 day')
		and date(ft2.txn_date) != date(ft1.txn_date)
		and ft1.city in ('부산','인천','대구','제주','대전','광주','수원','서울' )
		and ft2.city in ('미국','중국','유럽')
),
rule4 as(
	select txn_id, customer_id, txn_date, amount, channel, is_fraud
	from (select *, avg(amount) over(partition by customer_id) as avg_amount
		from fraud_transactions ) as summary
	where amount >= 3* avg_amount
),
result as(
	select *
	from (
		select ft.txn_id, ft.is_fraud,	
			(case when r1.txn_id is not null then 1 else 0 end+
			case when r2.txn_id is not null then 1 else 0 end +
			case when r3.txn_id is not null then 1 else 0 end +
			case when r4.txn_id is not null then 1 else 0 end) as count_rule
		from fraud_transactions ft
		left join rule1 r1 on r1.txn_id = ft.txn_id
		left join rule2 r2 on r2.txn_id = ft.txn_id
		left join rule3 r3 on r3.txn_id = ft.txn_id
		left join rule4 r4 on r4.txn_id = ft.txn_id) as summary
	where count_rule >=1	
)
select
	count(*) as 총탐수,
	count(*) filter( where is_fraud = true) as 정탐,
	count(*) filter( where is_fraud is not true) as 오탐,
	round(100.0* count(*) filter( where is_fraud = true)/count(*),2) as 정탐율,
	round(100.0* count(*) filter( where is_fraud = true)/
		(select count(*) from fraud_transactions where is_fraud = true) ,2) as 재현율,
	round(100.0* count(*) filter( where is_fraud is not true)/
		(select count(*) from fraud_transactions where is_fraud is not true) ,2) as 오탐율
from result

-- [비즈니스 목표별 2가지 방향 제시]
-- ================================================================
-- 방향 1: 오탐 최소화 우선 (Scenario A)
--   → 해외이상 Rule 제외
--   → 정탐률 100% + 오탐 0건 유지
--   → 정상 고객 불편 없음
--   → 수익 기회 손실 없음 
-- ================================================================
-- 방향 2: 재현율 최대화 우선 (Scenario B)
--   → 해외이상 Rule 포함
--   → 재현율 56.44%로 소폭 향상
--   → 오탐 7건 감수
--   → fraud 한 건도 놓치지 않기 우선 
-- ================================================================

-- [최종 결론]
-- 단일 정답 없음!
-- 비즈니스 목표에 따라 결정
-- 본 프로젝트에서는 Scenario A 기준으로
-- 해외이상 Rule 제외 후 Q17 진행
-- 재현율 우선 회사라면 포함 권장
-- ================================================================

-- ================================================================
-- Q18. 블랙리스트 등록 대상 고객 탐지
-- Q17 결과 기반 → 2가지 방향으로 분석
-- ================================================================

-- [방향 A: 해외이상 제외 — Rule 3개 기반]
-- Rule1: 보이스피싱
-- Rule2: 타지역 이상거래
-- Rule3: 평균 3배 이상
-- → 1개 이상 해당 고객 → 블랙리스트 대상

-- [방향 B: 해외이상 포함 — Rule 4개 기반]
-- Rule1: 보이스피싱
-- Rule2: 타지역 이상거래
-- Rule3: 해외이상
-- Rule4: 평균 3배 이상
-- → 1개 이상 해당 고객 → 블랙리스트 대상

-- [비교 목적]
-- 해외이상 Rule 추가 시
-- 블랙리스트 대상 고객 수 변화 확인
-- → 어떤 방향이 더 효과적인지 판단

-- Q18-A. 다음 중 2개 이상 해당하는 고객 → 블랙리스트 등록 대상
--      1) 보이스피싱 Rule:새벽 1시-5시 + 모바일 + 50만원 이상
-- 		2) 타지역 이상거래 (거주 도시와 다른 도시 고액 거래 50만원 이상)
--      3) 평균 3배 이상 거래 이력 있음
    -- → 1개 이상 해당 시 위험 고객으로 분류
with rule1 as(
	select txn_id, customer_id, txn_date,
		extract(hour from txn_date) as txn_hour,
		amount, channel, is_fraud	
	from fraud_transactions  
	where extract(hour from txn_date) between 1 and 5
		and channel = '모바일'
		and amount >= 500000
),
rule2 as(
	select ft.txn_id, ft.customer_id , ft.txn_date, ft.amount, ft.is_fraud,
			 ft.city as 거래도시, c.city as 거주도시
	from fraud_transactions ft 
	join customers c on ft.customer_id = c.customer_id 
	where ft.city != c.city and amount >= 500000
),
rule3 as(
	select txn_id, customer_id, txn_date, amount, channel, is_fraud
	from (select *, avg(amount) over(partition by customer_id) as avg_amount
		from fraud_transactions ) as summary
	where amount >= 3* avg_amount
)
select customer_id,위험패턴_수A
from (
	select ft.customer_id,
	 (case when r1.customer_id is not null then 1 else 0 end +
	 case when r2.customer_id is not null then 1 else 0 end +
	 case when r3.customer_id is not null then 1 else 0 end ) as 위험패턴_수A
	from (select distinct customer_id from fraud_transactions) ft
	left join (select distinct customer_id from rule1) r1 on r1.customer_id = ft.customer_id 
	left join (select distinct customer_id from rule2) r2 on r2.customer_id = ft.customer_id 
	left join (select distinct customer_id from rule3) r3 on r3.customer_id = ft.customer_id ) as summary
where 	위험패턴_수A >=1
order by 위험패턴_수A desc;


-- Q18-B. 다음 중 2개 이상 해당하는 고객 → 블랙리스트 등록 대상
--      1) 보이스피싱 Rule:새벽 1시-5시 + 모바일 + 50만원 이상
-- 		2) 타지역 이상거래 (거주 도시와 다른 도시 고액 거래 50만원 이상)
--      3) 평균 3배 이상 거래 이력 있음
--		4) 해외이상 Rule:4일 이내 국내+해외 동시 사용
    -- → 1개 이상 해당 시 위험 고객으로 분류
with rule1 as(
	select txn_id, customer_id, txn_date,
		extract(hour from txn_date) as txn_hour,
		amount, channel, is_fraud	
	from fraud_transactions  
	where extract(hour from txn_date) between 1 and 5
		and channel = '모바일'
		and amount >= 500000
),
rule2 as(
	select ft.txn_id, ft.customer_id , ft.txn_date, ft.amount, ft.is_fraud,
			 ft.city as 거래도시, c.city as 거주도시
	from fraud_transactions ft 
	join customers c on ft.customer_id = c.customer_id 
	where ft.city != c.city and amount >= 500000
),
rule3 as(
	select txn_id, customer_id, txn_date, amount, channel, is_fraud
	from (select *, avg(amount) over(partition by customer_id) as avg_amount
		from fraud_transactions ) as summary
	where amount >= 3* avg_amount
),
rule4 as(
	select ft1.txn_id, ft1.customer_id , ft1.txn_date, ft1.amount, ft1.is_fraud,
		ft1.city as 국내거래, ft2.city as 해외거래
	from fraud_transactions ft1
	join fraud_transactions ft2 on ft1.customer_id = ft2.customer_id
	where date(ft2.txn_date) between date(ft1.txn_date) and  (date(ft1.txn_date) + interval '4 day')
		and date(ft2.txn_date) != date(ft1.txn_date)
		and ft1.city in ('부산','인천','대구','제주','대전','광주','수원','서울' )
		and ft2.city in ('미국','중국','유럽')
)		
select customer_id,위험패턴_수B
from (
	select ft.customer_id,
	 (case when r1.customer_id is not null then 1 else 0 end +
	 case when r2.customer_id is not null then 1 else 0 end +
	 case when r3.customer_id is not null then 1 else 0 end +  
	 case when r4.customer_id is not null then 1 else 0 end) as 위험패턴_수B
	from (select distinct customer_id from fraud_transactions) ft
	left join (select distinct customer_id from rule1) r1 on r1.customer_id = ft.customer_id 
	left join (select distinct customer_id from rule2) r2 on r2.customer_id = ft.customer_id 
	left join (select distinct customer_id from rule3) r3 on r3.customer_id = ft.customer_id 
	left join (select distinct customer_id from rule4) r4 on r4.customer_id = ft.customer_id) as summary
where 	위험패턴_수B >=1
order by 위험패턴_수B desc;

-- ================================================================
-- [Q18-A vs Q18-B 비교 분석]
-- Q18-A: 135명 / Q18-B: 136명 → 차이 1명
-- → Q18-A에서 놓친 고객이 누구인지 확인!
-- → 해당 고객이 실제 fraud인지 검증!
-- ================================================================

with rule1 as(
	select txn_id, customer_id, txn_date,
		extract(hour from txn_date) as txn_hour,
		amount, channel, is_fraud	
	from fraud_transactions  
	where extract(hour from txn_date) between 1 and 5
		and channel = '모바일'
		and amount >= 500000
),
rule2 as(
	select ft.txn_id, ft.customer_id , ft.txn_date, ft.amount, ft.is_fraud,
			 ft.city as 거래도시, c.city as 거주도시
	from fraud_transactions ft 
	join customers c on ft.customer_id = c.customer_id 
	where ft.city != c.city and amount >= 500000
),
rule3 as(
	select txn_id, customer_id, txn_date, amount, channel, is_fraud
	from (select *, avg(amount) over(partition by customer_id) as avg_amount
		from fraud_transactions ) as summary
	where amount >= 3* avg_amount
),
rule4 as(
	select ft1.txn_id, ft1.customer_id , ft1.txn_date, ft1.amount, ft1.is_fraud,
		ft1.city as 국내거래, ft2.city as 해외거래
	from fraud_transactions ft1
	join fraud_transactions ft2 on ft1.customer_id = ft2.customer_id
	where date(ft2.txn_date) between date(ft1.txn_date) and  (date(ft1.txn_date) + interval '4 day')
		and date(ft2.txn_date) != date(ft1.txn_date)
		and ft1.city in ('부산','인천','대구','제주','대전','광주','수원','서울' )
		and ft2.city in ('미국','중국','유럽')
),
blacklistA as(
	select customer_id,위험패턴_수A
	from (
		select ft.customer_id,
	 		(case when r1.customer_id is not null then 1 else 0 end +
	 		case when r2.customer_id is not null then 1 else 0 end +
	 		case when r3.customer_id is not null then 1 else 0 end) as 위험패턴_수A
			from (select distinct customer_id from fraud_transactions) ft
			left join (select distinct customer_id from rule1) r1 on r1.customer_id = ft.customer_id 
			left join (select distinct customer_id from rule2) r2 on r2.customer_id = ft.customer_id 
			left join (select distinct customer_id from rule3) r3 on r3.customer_id = ft.customer_id) as summary
	where 	위험패턴_수A >=1
),
blacklistB as (
	select customer_id,위험패턴_수B
	from (
		select ft.customer_id,
	 		(case when r1.customer_id is not null then 1 else 0 end +
	 		case when r2.customer_id is not null then 1 else 0 end +
	 		case when r3.customer_id is not null then 1 else 0 end +  
	 		case when r4.customer_id is not null then 1 else 0 end) as 위험패턴_수B
			from (select distinct customer_id from fraud_transactions) ft
			left join (select distinct customer_id from rule1) r1 on r1.customer_id = ft.customer_id 
			left join (select distinct customer_id from rule2) r2 on r2.customer_id = ft.customer_id 
			left join (select distinct customer_id from rule3) r3 on r3.customer_id = ft.customer_id 
			left join (select distinct customer_id from rule4) r4 on r4.customer_id = ft.customer_id) as summary
	where 	위험패턴_수B >=1
)
select     b.customer_id,
    		ft.txn_id, ft.is_fraud, ft.amount, ft.city AS 거래도시, ft.txn_date,
    		'해외이상으로 추가' AS 사유
from(
	select customer_id from blacklistB
	except 
	select customer_id from blacklistA) as b
join fraud_transactions ft on b.customer_id = ft.customer_id
order by b.customer_id, ft.txn_date;

-- ================================================================
-- [검증 결과]
-- Q18-A에서 놓친 고객 1명 → is_fraud = TRUE
-- → 해외이상 Rule이 실제 fraud를 탐지!
-- → Q18-A는 이 fraud 고객을 놓쳤음!

-- [최종 결론]
-- 오탐 최소화 우선 (현대카드/한패스):
--   → Q17-A 선택: 오탐 0건 유지
--   → 단, fraud 1명 놓침 감수

-- 재현율 우선 (토스/카카오페이):
--   → Q17-B 선택: fraud 1명 추가 탐지
--   → 단, 오탐 7건 발생 감수

-- → 비즈니스 목표에 따라 최종 선택!
-- ================================================================


-- ================================================================
-- [데이터셋 한계 및 Rule 제약사항]
-- ================================================================

-- 1. 입회사기 Rule 제외
--    → join_date 랜덤 생성으로
--      가입 직후 fraud 패턴 재현 불가
--    → 실무: 가입 후 일수별 fraud율 분석으로
--      최적 임계값 도출 가능

-- 2. 카드복제 Rule 효과 미미
--    → 2000건 소규모 데이터셋으로
--      1시간 내 반복 거래 패턴 부족
--    → 실무: 수백만건 데이터에서
--      패턴 명확히 나타남

-- 3. 해외이상 Rule 신뢰도 낮음
--    → 국내+해외 동시 사용 4건으로
--      통계적 신뢰도 부족
--    → 실무: 충분한 데이터로
--      더 정확한 임계값 도출 가능

-- 4. 전반적 건수 부족
--    → 500명 고객 / 2000건 거래
--    → 실무: 수백만건 기준으로
--      더 정교한 Rule 설계 가능

-- [그럼에도 불구하고 증명된 것]
-- 1. 타지역 fraud율 100% → Rule2 확정
-- 2. 새벽 1~5시 fraud율 18~28% → Rule1 확정
-- 3. 50만원 임계값 → 데이터로 증명
-- 4. 평균 3배 임계값 → 데이터로 증명
-- 5. ATM 채널 제외 → fraud율 0% 확인
-- ================================================================






