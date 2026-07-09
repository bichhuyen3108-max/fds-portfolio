-- Table: customers
CREATE TABLE public.customers (
	customer_id varchar(10) NOT NULL,
	age int4 NULL,
	gender varchar(1) NULL,
	city varchar(20) NULL,
	job_type varchar(20) NULL,
	monthly_income int4 NULL,
	credit_grade varchar(2) NULL,
	join_date date NULL,
	CONSTRAINT customers_pkey PRIMARY KEY (customer_id)
);


-- Table: fraud_transactions

CREATE TABLE public.fraud_transactions (
	txn_id varchar(12) NOT NULL,
	customer_id varchar(10) NULL,
	txn_date timestamp NULL,
	amount int4 NULL,
	merchant_type varchar(20) NULL,
	channel varchar(10) NULL,
	city varchar(20) NULL,
	is_fraud bool NULL,
	fraud_type varchar(20) NULL,
	CONSTRAINT fraud_transactions_pkey PRIMARY KEY (txn_id)
);


-- public.fraud_transactions foreign keys

ALTER TABLE public.fraud_transactions ADD CONSTRAINT fraud_transactions_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id);

