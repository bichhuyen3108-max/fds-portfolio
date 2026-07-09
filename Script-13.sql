-- =============================================
-- FRAUD FDS 실전 연습 문제집
-- 현대카드 사고FDS팀 대비
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
-- Q6. 동일 고객이 1시간 내에 3건 이상 거래한 경우를 찾으세요.
--     (단기 반복 거래 = 카드복제 패턴)
	
select t1.customer_id , 
		count(t2.txn_id) as count_txn
from fraud_transactions t1
join fraud_transactions t2 
	on t1.customer_id = t2.customer_id 
	and t2.txn_date >= t1.txn_date 
	and t2.txn_date <= t1.txn_date + interval '1 hour'
group by   t1.customer_id
having count(t1.txn_id) >=3;	

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
--     같은 날 국내 거래도 있는 고객을 찾으세요.
--     (해외+국내 동시 사용 = 카드복제 의심)
select distinct city
from fraud_transactions ;

select fd1.txn_date as 국내날자, fd2.txn_date as 해외날자,
	fd1.customer_id, fd1.amount as 국내거래_금액, fd2.amount as 해외거래_금액,
	fd1.city as 국내, fd2.city as 해외거래, fd1.is_fraud
from fraud_transactions fd1
join fraud_transactions fd2 	
	on fd1.customer_id =fd2.customer_id 
	and DATE(fd1.txn_date) = DATE(fd2.txn_date)
where fd2.city in ('미국','중국','유럽') 
		and fd1.city in ('부산','인천','대구','제주','대전','광주','수원','서울'); 

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

-- Q15. [종합] 다음 조건을 모두 만족하는 고위험 거래를 탐지하세요:
--      1) 새벽 시간대(00~05시)
--      2) 거래금액 100만원 이상
--      3) 채널이 모바일 또는 온라인
--      4) 고객 평균 거래금액의 3배 이상
--		다음에 이 Rule별 정탐률과 재현률과 오탐률을 구하세요.
with fraud_transactions_summary as (
	select *,
		extract(hour from txn_date) as txn_hour,
		round(avg(amount) over(partition by customer_id),2) as avg_amount
	from fraud_transactions 	
),
rule2 as(
	select *
	from fraud_transactions_summary
	where (txn_hour between 0 and 5) and 
		amount >= 1000000 and 
		channel in ('모바일','온라인') and
		amount >= 3*avg_amount
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

-- Q16. 다음 중 2개 이상 해당하는 고객 → 블랙리스트 등록 대상
    -- 패턴1: 1시간 내 반복 거래 이력 있음
    -- 패턴2: 평균 5배 이상 거래 이력 있음  
    -- 패턴3: 해외+국내 동시 사용 이력 있음
    -- → 2개 이상 해당 시 위험 고객으로 분류


with pattern1 as(
	select ft1.customer_id , ft2.txn_date 
	from fraud_transactions ft1
	join fraud_transactions ft2 on ft1.customer_id = ft2.customer_id
	where ft2.txn_date <= ft1.txn_date + interval '1hour' 
		and ft2.txn_date > ft1.txn_date
		and ft2.txn_id != ft1.txn_id
),
pattern2 as(
	select
		customer_id , amount
	from (select customer_id, amount,
			round(avg(amount) over(partition by customer_id),2) as avg_amount
		from fraud_transactions
		) as sub	
	where amount >= 5*avg_amount
),
pattern3 as (
	select ft1.customer_id ,
			ft1.city as 국내거래,
			ft2.city as 해외거래
	from fraud_transactions ft1
	join fraud_transactions ft2 on ft1.customer_id = ft2.customer_id
	where ft1.city in ('부산','인천','대구','제주','대전','광주','수원','서울') 
		and ft2.city in ('유럽','중국','미국')
		and date(ft1.txn_date ) = date(ft2.txn_date )
)

select customer_id , 위험패턴_수
from (select
			ft.customer_id ,
			(case when p1.customer_id is not null then 1 else 0 end +
			case when p2.customer_id  is not null then 1 else 0 end +
			case when p3.customer_id  is not null then 1 else 0 end ) as 위험패턴_수
		from ( select distinct customer_id from fraud_transactions ) as ft
		left join (select distinct customer_id from pattern1 )p1 
			on ft.customer_id = p1.customer_id
		left join (select distinct customer_id from pattern2) p2 
			on ft.customer_id = p2.customer_id
		left join (select distinct customer_id from pattern3) p3 
			on ft.customer_id = p3.customer_id) as sub
where 위험패턴_수 >=2
order by 위험패턴_수 desc
