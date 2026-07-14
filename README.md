# SQL Portfolio — 이상금융거래탐지 (FDS)

> **지원 직무:** FDS 모니터링 / Fraud Analyst  
> **지원 기업:** Hanpass  
> **사용 DB:** PostgreSQL  
> **작성자:** Hoàng Thị Bích Huyền (황티빅후엔)

---

## 소개

안녕하세요. 저는 베트남 출신으로 현재 한국에 거주하며 금융 데이터 분야에서 커리어를 쌓고 있습니다. 숭실대학교(Soongsil University)에서 Finance/Real Estate MBA를 마쳤고, 현재는 Korea IT Academy에서 JAVA & PYTHON 기반 빅데이터 분석 AI 플랫폼 개발자 과정을 수강 중입니다. TOPIK II 5급을 보유하고 있으며, SQL·Python을 활용한 데이터 분석 프로젝트를 꾸준히 진행하고 있습니다.

이 포트폴리오는 Hanpass FDS 모니터링 업무를 염두에 두고, 실무에서 실제로 쓰일 수 있는 이상거래 탐지 쿼리를 PostgreSQL로 직접 구현한 것입니다. 데이터 파악 → 변수 분석 → AND/OR Rule 비교 → 최종 최적화 → 블랙리스트까지, 완결된 FDS 분석 흐름을 보여줍니다.

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

---

## 포트폴리오 구성 (총 22개)

### 01. 기본 집계 ⭐

| 파일 | 내용 | 기법 |
|------|------|------|
| Q01_fraud_rate_overview.sql | 전체 fraud 건수 및 비율 | CASE WHEN, FILTER |
| Q02_fraud_by_type.sql | fraud 유형별 건수·평균금액 | GROUP BY, AVG |
| Q03_fraud_by_channel.sql | 채널별 fraud 건수 | FILTER |
| Q14_fraud_by_credit_grade.sql | 신용등급별 fraud 발생률 | JOIN + GROUP BY |

### 02. 날짜·시간 함수 ⭐⭐

| 파일 | 내용 | 기법 |
|------|------|------|
| Q04_late_night_analysis.sql | 새벽 정상 vs fraud 비교 | EXTRACT(HOUR) |
| Q10_new_customer_fraud.sql | 가입 7일 이내 고액 거래 | INTERVAL |
| Q12_monthly_fraud_trend.sql | 월별 fraud 추이 | DATE_TRUNC, CTE |
| Q13_fraud_by_time_slot.sql | 시간대별 fraud 유형 분석 | EXTRACT + CASE WHEN |

### 03. CTE ⭐⭐

| 파일 | 내용 | 기법 |
|------|------|------|
| Q05_customer_avg_stats.sql | 고객 평균 거래 (서브쿼리 vs CTE) | WITH, 인라인 뷰 |

### 04. JOIN 기반 탐지 ⭐⭐⭐

| 파일 | 내용 | 기법 |
|------|------|------|
| Q06_rapid_repeat_txn.sql | 1시간 내 2건+ 반복 거래 + string_agg | Self-JOIN, string_agg |
| Q08_out_of_area_txn.sql | 거주지 외 도시 거래 탐지 | JOIN + 부등호 |
| Q09_simultaneous_domestic_overseas.sql | 4일 이내 국내+해외 동시 거래 | Self-JOIN, BETWEEN |

### 05. 윈도우 함수 ⭐⭐⭐

| 파일 | 내용 | 기법 |
|------|------|------|
| Q07_high_value_anomaly.sql | 개인 평균 5배 이상 거래 탐지 | AVG() OVER PARTITION BY |
| Q11_rule_tp_fp_analysis.sql | Rule 성능 — Precision/Recall/FP Rate | Multi-CTE + 스칼라 서브쿼리 |

### 06. AND vs OR 복합 조건 비교 ⭐⭐⭐⭐

| 파일 | 결과 | 기법 |
|------|------|------|
| Q15_composite_risk_score.sql | 정탐률 100%, 오탐 0건, 재현율 12% | 5조건 AND + JOIN customers |
| Q16_or_composite_rule.sql | 재현율 100%, 오탐 1,412건 | 5 Rule OR + LEFT JOIN |

### 07. 변수 상관관계 분석 — Rule 임계값 근거 ⭐⭐⭐

| 파일 | 검증 내용 | 결론 |
|------|----------|------|
| A1_time_fraud_rate.sql | 시간대별 fraud율 | 새벽 1~5시 확정 (fraud율 18~28%) |
| A2_amount_threshold.sql | 금액 임계값 비교 | 50만원 확정 (정탐률 98.88%) |
| A3_channel_analysis.sql | 채널별 fraud율 | ATM 제외 확정 (ATM 0%) |
| A4_outofarea_analysis.sql | 타지역 거래 | fraud율 100%, 오탐 0건 — 최강 신호 |
| A5_avg_multiplier_analysis.sql | 개인 평균 배수 | 3배 확정 (정탐률 100%) |

### 08. 비즈니스 목적별 최종 Rule 비교 ⭐⭐⭐⭐⭐

| 파일 | 내용 | 결과 |
|------|------|------|
| Q17A_final_rule_no_overseas.sql | 3 Rule OR — 오탐 최소화 | 정탐률 100%, 오탐 0건 |
| Q17B_final_rule_with_overseas.sql | 4 Rule OR — 재현율 향상 | 오탐 7건, fraud 1건 추가 |

### 09. 블랙리스트 탐지 ⭐⭐⭐⭐⭐

| 파일 | 내용 | 결과 |
|------|------|------|
| Q18A_blacklist_3rules.sql | 거래→고객 단위, 3 Rule 블랙리스트 | 135명 탐지 |
| Q18B_blacklist_4rules.sql | 해외이상 포함 + EXCEPT 검증 | 136명, fraud 1명 추가 확인 |

---

## 참고

- 원본 쿼리: [`Script-13.sql`](./Script-13.sql) / 스키마: [`schema.sql`](./schema.sql)
- GitHub: [bichhuyen3108-max](https://github.com/bichhuyen3108-max)
- Portfolio: [bichhuyen3108-max.github.io/portfolio](https://bichhuyen3108-max.github.io/portfolio/)
