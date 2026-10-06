-- Creates the fictional Lakota Bank "source system" inside your course database
-- and loads day 1. Safe to re-run: it drops and recreates only the src_core schema.
-- Run from the course/data folder:  psql "$PGURL_SRC" -f sql/01_source_init.sql
\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS src_core CASCADE;
CREATE SCHEMA src_core;

CREATE TABLE src_core.customers (
    customer_id integer PRIMARY KEY,
    first_name  text,
    last_name   text,
    email       text,
    branch_id   integer,
    status      text,
    created_at  timestamp,
    updated_at  timestamp
);

CREATE TABLE src_core.accounts (
    account_id   integer PRIMARY KEY,
    customer_id  integer,
    product_code text,
    opened_date  date,
    status       text,
    balance      numeric(14,2),
    updated_at   timestamp
);

CREATE TABLE src_core.transactions (
    txn_id     integer PRIMARY KEY,
    account_id integer,
    txn_ts     timestamp,
    amount     numeric(14,2),
    txn_type   text,
    channel    text
);

\copy src_core.customers    FROM 'day1/customers.csv'    WITH (FORMAT csv, HEADER true)
\copy src_core.accounts     FROM 'day1/accounts.csv'     WITH (FORMAT csv, HEADER true)
\copy src_core.transactions FROM 'day1/transactions.csv' WITH (FORMAT csv, HEADER true)

SELECT 'customers' AS tbl, count(*) FROM src_core.customers
UNION ALL SELECT 'accounts', count(*) FROM src_core.accounts
UNION ALL SELECT 'transactions', count(*) FROM src_core.transactions;
