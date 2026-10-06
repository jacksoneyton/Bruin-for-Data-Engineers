-- Applies business day 2 to src_core: new and changed customers and accounts (upserts),
-- one hard-deleted account, and new transactions. Run after day 1 has been applied.
-- Run from the course/data folder:  psql "$PGURL_SRC" -f sql/02_source_day2.sql
\set ON_ERROR_STOP on

CREATE TEMP TABLE stg_customers (LIKE src_core.customers);
CREATE TEMP TABLE stg_accounts  (LIKE src_core.accounts);
CREATE TEMP TABLE stg_deleted   (account_id integer);

\copy stg_customers FROM 'day2/customers.csv'        WITH (FORMAT csv, HEADER true)
\copy stg_accounts  FROM 'day2/accounts.csv'         WITH (FORMAT csv, HEADER true)
\copy stg_deleted   FROM 'day2/deleted_accounts.csv' WITH (FORMAT csv, HEADER true)
\copy src_core.transactions FROM 'day2/transactions.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO src_core.customers
SELECT * FROM stg_customers
ON CONFLICT (customer_id) DO UPDATE SET
    first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name,
    email = EXCLUDED.email, branch_id = EXCLUDED.branch_id,
    status = EXCLUDED.status, updated_at = EXCLUDED.updated_at;

INSERT INTO src_core.accounts
SELECT * FROM stg_accounts
ON CONFLICT (account_id) DO UPDATE SET
    customer_id = EXCLUDED.customer_id, product_code = EXCLUDED.product_code,
    opened_date = EXCLUDED.opened_date, status = EXCLUDED.status,
    balance = EXCLUDED.balance, updated_at = EXCLUDED.updated_at;

DELETE FROM src_core.accounts WHERE account_id IN (SELECT account_id FROM stg_deleted);

SELECT 'customers' AS tbl, count(*) FROM src_core.customers
UNION ALL SELECT 'accounts', count(*) FROM src_core.accounts
UNION ALL SELECT 'transactions', count(*) FROM src_core.transactions;
