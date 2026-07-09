# SQL Portfolio — 이상금융거래탐지 (FDS)

> **지원 직무:** FDS 모니터링 / Fraud Analyst  
> **지원 기업:** Hanpass  
> **사용 DB:** PostgreSQL  
> **작성자:** Hoàng Thị Bích Huyền (황티빅후엔)

---

## 소개

안녕하세요. 저는 베트남 출신으로 현재 한국에 거주하며 금융 데이터 분야에서 커리어를 쌓고 있습니다. 숭실대학교(Soongsil University)에서 Finance/Real Estate MBA를 마쳤고, 현재는 Korea IT Academy에서 JAVA & PYTHON 기반 빅데이터 분석 AI 플랫폼 개발자 과정을 수강 중입니다. TOPIK II 5급을 보유하고 있으며, SQL·Python을 활용한 데이터 분석 프로젝트를 꾸준히 진행하고 있습니다.

금융권 Fraud Analyst 직무에 관심을 갖게 된 건 MBA 과정에서 금융 리스크와 데이터를 함께 다루면서부터입니다. 이상거래 탐지는 재무 지식과 데이터 분석이 결합되어야 하는 분야라, 제 배경을 가장 잘 살릴 수 있는 방향이라고 생각했습니다.

이 포트폴리오는 Hanpass FDS 모니터링 업무를 염두에 두고, 실무에서 실제로 쓰일 수 있는 이상거래 탐지 쿼리를 PostgreSQL로 직접 구현한 것입니다. 단순 집계에서 시작해 Rule 성능 평가와 블랙리스트 탐지까지, 난이도를 단계적으로 높이는 방식으로 구성했습니다.

---

## 관련 프로젝트

- **한국 반도체 포트폴리오 시장위험 분석** — Samsung Electronics, SK Hynix, Samsung SDI 포트폴리오에 대해 Historical VaR, GARCH VaR, Kupiec POF Test, Stress Testing을 Python으로 구현
  - GitHub: [semiconductor-portfolio-risk](https://github.com/bichhuyen3108-max/semiconductor-portfolio-risk)
  - Portfolio: [bichhuyen3108-max.github.io/portfolio](https://bichhuyen3108-max.github.io/portfolio/)

---

## 데이터 구조

```
customers
├── customer_id   (PK)
├── age, gender, city, job_type
├── monthly_income, credit_grade
└── join_date

fraud_transactions
├── txn_id        (PK)
├── customer_id   (FK → customers)
├── txn_date      (timestamp)
├── amount, merchant_type, channel, city
├── is_fraud      (bool)
└── fraud_type
```

> 스키마 전체는 [`schema.sql`](./schema.sql)에서 확인할 수 있습니다.

---

## 포트폴리오 구성

총 16개 쿼리를 SQL 기법과 난이도 기준으로 6개 섹션으로 분류했습니다.

---

### 01. 기본 집계 (Basic Aggregation) ⭐

FDS 데이터를 처음 접할 때 가장 먼저 확인하는 현황 파악 쿼리들입니다.

| 파일 | 내용 | 핵심 기법 |
|------|------|-----------|
| [Q01_fraud_rate_overview.sql](./portfolio/01_basic_aggregation/Q01_fraud_rate_overview.sql) | 전체 거래 중 fraud 건수 및 비율 | CASE WHEN, FILTER |
| [Q02_fraud_by_type.sql](./portfolio/01_basic_aggregation/Q02_fraud_by_type.sql) | fraud 유형별 건수 및 평균 금액 | GROUP BY, AVG |
| [Q03_fraud_by_channel.sql](./portfolio/01_basic_aggregation/Q03_fraud_by_channel.sql) | 채널별 fraud 발생 건수 | FILTER 집계 |
| [Q14_fraud_by_credit_grade.sql](./portfolio/01_basic_aggregation/Q14_fraud_by_credit_grade.sql) | 신용등급별 fraud 발생률 | JOIN + GROUP BY |

---

### 02. 날짜·시간 함수 (Date-Time Functions) ⭐⭐

거래 시간 패턴을 분석하는 쿼리들입니다. FDS에서 시간 정보는 매우 중요한 탐지 신호입니다.

| 파일 | 내용 | 핵심 기법 |
|------|------|-----------|
| [Q04_late_night_analysis.sql](./portfolio/02_datetime_functions/Q04_late_night_analysis.sql) | 새벽(00~05시) 정상 vs fraud 비교 | EXTRACT(HOUR) |
| [Q10_new_customer_fraud.sql](./portfolio/02_datetime_functions/Q10_new_customer_fraud.sql) | 가입 7일 이내 고액 거래 탐지 | 날짜 산술, INTERVAL |
| [Q12_monthly_fraud_trend.sql](./portfolio/02_datetime_functions/Q12_monthly_fraud_trend.sql) | 월별 fraud 발생 추이 | DATE_TRUNC, CTE |
| [Q13_fraud_by_time_slot.sql](./portfolio/02_datetime_functions/Q13_fraud_by_time_slot.sql) | fraud 유형별 주요 발생 시간대 분석 | EXTRACT + CASE WHEN |

---

### 03. CTE (Common Table Expressions) ⭐⭐

서브쿼리와 CTE를 비교하고, 복잡한 쿼리를 단계별로 분리하는 방식을 다룹니다.

| 파일 | 내용 | 핵심 기법 |
|------|------|-----------|
| [Q05_customer_avg_stats.sql](./portfolio/03_cte/Q05_customer_avg_stats.sql) | 고객 1인당 평균 거래 건수·금액 (서브쿼리 vs CTE 비교) | WITH, 인라인 뷰 |

---

### 04. JOIN 기반 이상거래 탐지 (JOIN-based Anomaly Detection) ⭐⭐⭐

여러 테이블 또는 같은 테이블을 두 번 조인하여 이상 패턴을 찾는 쿼리들입니다.

| 파일 | 내용 | 핵심 기법 |
|------|------|-----------|
| [Q06_rapid_repeat_txn.sql](./portfolio/04_join_anomaly_detection/Q06_rapid_repeat_txn.sql) | 1시간 내 3건 이상 반복 거래 탐지 (카드복제 패턴) | Self-JOIN, INTERVAL |
| [Q08_out_of_area_txn.sql](./portfolio/04_join_anomaly_detection/Q08_out_of_area_txn.sql) | 거주지 외 도시 거래 탐지 | JOIN + 부등호 조건 |
| [Q09_simultaneous_domestic_overseas.sql](./portfolio/04_join_anomaly_detection/Q09_simultaneous_domestic_overseas.sql) | 같은 날 국내+해외 동시 거래 (불가능 여행) | Self-JOIN, DATE() |

---

### 05. 윈도우 함수 (Window Functions) ⭐⭐⭐

개인화 탐지와 Rule 성능 분석에 윈도우 함수를 활용한 쿼리들입니다.

| 파일 | 내용 | 핵심 기법 |
|------|------|-----------|
| [Q07_high_value_anomaly.sql](./portfolio/05_window_functions/Q07_high_value_anomaly.sql) | 고객 평균의 5배 이상 거래 탐지 | AVG() OVER (PARTITION BY) |
| [Q11_rule_tp_fp_analysis.sql](./portfolio/05_window_functions/Q11_rule_tp_fp_analysis.sql) | Rule 성능 평가 — 정탐률 / 재현율 / 오탐률 | Multi-CTE + Window + 스칼라 서브쿼리 |

---

### 06. 복합 조건 탐지 (Multi-condition Detection) ⭐⭐⭐⭐

여러 위험 신호를 조합하여 고위험 거래와 고위험 고객을 선별하는 쿼리들입니다.

| 파일 | 내용 | 핵심 기법 |
|------|------|-----------|
| [Q15_composite_risk_score.sql](./portfolio/06_multi_condition_detection/Q15_composite_risk_score.sql) | 새벽+고액+비대면+개인평균 5배 복합 탐지 + Rule 성능 평가 | CTE + Window + 다중 AND + 스칼라 서브쿼리 |
| [Q16_blacklist_detection.sql](./portfolio/06_multi_condition_detection/Q16_blacklist_detection.sql) | 3가지 패턴 중 2개 이상 해당 고객 블랙리스트 탐지 | Multi-CTE + Self-JOIN + LEFT JOIN + 점수 합산 |

---

## SQL 기법 요약

| 기법 | 활용 쿼리 |
|------|-----------|
| FILTER 조건부 집계 | Q01, Q03, Q04, Q11, Q14, Q15 |
| EXTRACT / DATE_TRUNC | Q04, Q12, Q13, Q15 |
| 날짜 산술 (INTERVAL) | Q06, Q10, Q16 |
| CTE (WITH) | Q05, Q07, Q11, Q12, Q15, Q16 |
| Self-JOIN | Q06, Q09, Q16 |
| Window Function (AVG OVER PARTITION BY) | Q07, Q11, Q15, Q16 |
| 스칼라 서브쿼리 (분모 계산) | Q11, Q15 |
| LEFT JOIN + 점수 합산 | Q16 |
| 복합 조건 (AND + IN) | Q09, Q15 |

---

## 참고

- 원본 쿼리 파일: [`Script-13.sql`](./Script-13.sql)
- 테이블 스키마: [`schema.sql`](./schema.sql)
- 포트폴리오 개별 파일: [`portfolio/`](./portfolio/) 디렉토리
- GitHub: [bichhuyen3108-max](https://github.com/bichhuyen3108-max)
- Portfolio site: [bichhuyen3108-max.github.io/portfolio](https://bichhuyen3108-max.github.io/portfolio/)
