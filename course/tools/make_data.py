"""Generate the synthetic Lakota Bank data used by the course.

Deterministic: the same seed always produces the same files.
All names, branches and amounts are invented. Standard library only.

Usage (from the course/ folder):
    python tools/make_data.py
"""
import csv
import os
import random
from datetime import date, datetime, timedelta

SEED = 20260101
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
rng = random.Random(SEED)

FIRST = ["Aiyana", "Ben", "Carla", "Dev", "Elena", "Frank", "Grace", "Hector", "Ines", "Jonah",
         "Kai", "Lena", "Marco", "Nora", "Omar", "Priya", "Quinn", "Rosa", "Sam", "Tara",
         "Uma", "Victor", "Wren", "Xavier", "Yuki", "Zane"]
LAST = ["Anders", "Brave", "Castillo", "Dahl", "Eagle", "Fischer", "Gomez", "Haugen", "Ito",
        "Jensen", "Klein", "Larson", "Moreau", "Nguyen", "Olson", "Patel", "Quist", "Reyes",
        "Sorensen", "Thorne", "Underwood", "Voss", "Walker", "Young", "Zimmer"]

BRANCHES = [
    (1, "Lakota Main", "Pierre", "SD", "1998-03-02"),
    (2, "Lakota Riverfront", "Fort Pierre", "SD", "2004-07-19"),
    (3, "Lakota Prairie", "Huron", "SD", "2007-01-08"),
    (4, "Lakota Badlands", "Wall", "SD", "2011-05-23"),
    (5, "Lakota Capitol", "Bismarck", "ND", "2013-09-30"),
    (6, "Lakota Sunrise", "Mandan", "ND", "2016-02-11"),
    (7, "Lakota Digital", "Remote", "SD", "2020-06-01"),
    (8, "Lakota Northgate", "Minot", "ND", "2022-10-17"),
]
PRODUCTS = [
    ("CHK-BASIC", "Basic Checking", "CHECKING", "0.0000"),
    ("CHK-PLUS", "Plus Checking", "CHECKING", "0.0010"),
    ("SAV-STD", "Standard Savings", "SAVINGS", "0.0150"),
    ("SAV-HY", "High Yield Savings", "SAVINGS", "0.0400"),
    ("LN-AUTO", "Auto Loan", "LOAN", "0.0690"),
    ("LN-HOME", "Home Loan", "LOAN", "0.0610"),
]
CHANNELS = ["BRANCH", "ATM", "ONLINE", "MOBILE", "ACH"]


def w(path, header, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        wr = csv.writer(f, lineterminator="\n")
        wr.writerow(header)
        wr.writerows(rows)


def ts(d, h=None):
    h = rng.randint(7, 20) if h is None else h
    return datetime(d.year, d.month, d.day, h, rng.randint(0, 59), rng.randint(0, 59))


def fmt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


# ---- reference data (static) ----
w(os.path.join(OUT, "ref", "branches.csv"),
  ["branch_id", "branch_name", "city", "state", "opened_date"], BRANCHES)
w(os.path.join(OUT, "ref", "products.csv"),
  ["product_code", "product_name", "product_type", "interest_rate"], PRODUCTS)

# ---- state ----
customers = {}   # id -> dict
accounts = {}
next_cust = 1
next_acct = 1000
next_txn = 1

DAYS = [date(2026, 1, 1), date(2026, 1, 2), date(2026, 1, 3), date(2026, 1, 4)]


def new_customer(created):
    global next_cust
    cid = next_cust
    next_cust += 1
    fn, ln = rng.choice(FIRST), rng.choice(LAST)
    customers[cid] = dict(customer_id=cid, first_name=fn, last_name=ln,
                          email=f"{fn}.{ln}{cid}@example.test".lower(),
                          branch_id=rng.randint(1, len(BRANCHES)), status="ACTIVE",
                          created_at=created, updated_at=created)
    return cid


def new_account(cid, opened):
    global next_acct
    aid = next_acct
    next_acct += 1
    accounts[aid] = dict(account_id=aid, customer_id=cid,
                         product_code=rng.choice(PRODUCTS)[0],
                         opened_date=opened.date().isoformat(), status="OPEN",
                         balance=round(rng.uniform(50, 25000), 2), updated_at=opened)
    return aid


def txns_for(day, n):
    global next_txn
    rows = []
    open_ids = [a for a, v in accounts.items() if v["status"] == "OPEN"]
    for _ in range(n):
        aid = rng.choice(open_ids)
        kind = rng.choice(["DEPOSIT", "WITHDRAWAL", "PAYMENT", "FEE"])
        amt = round(rng.uniform(5, 1500), 2)
        if kind in ("WITHDRAWAL", "PAYMENT", "FEE"):
            amt = -amt if kind != "FEE" else -round(rng.uniform(1, 35), 2)
        rows.append([next_txn, aid, fmt(ts(day)), f"{amt:.2f}", kind, rng.choice(CHANNELS)])
        next_txn += 1
    return rows


def cust_row(c):
    return [c["customer_id"], c["first_name"], c["last_name"], c["email"], c["branch_id"],
            c["status"], fmt(c["created_at"]), fmt(c["updated_at"])]


def acct_row(a):
    return [a["account_id"], a["customer_id"], a["product_code"], a["opened_date"],
            a["status"], f"{a['balance']:.2f}", fmt(a["updated_at"])]


CUST_H = ["customer_id", "first_name", "last_name", "email", "branch_id", "status", "created_at", "updated_at"]
ACCT_H = ["account_id", "customer_id", "product_code", "opened_date", "status", "balance", "updated_at"]
TXN_H = ["txn_id", "account_id", "txn_ts", "amount", "txn_type", "channel"]

# ---- day 1: initial load, history through 2026-01-02 ----
d1 = DAYS[0]
for _ in range(60):
    c = new_customer(ts(d1 - timedelta(days=rng.randint(30, 900)), 9))
for cid in list(customers):
    for _ in range(rng.choice([1, 1, 2])):
        new_account(cid, customers[cid]["created_at"])
t1 = txns_for(DAYS[0], 70) + txns_for(DAYS[1], 80)
w(os.path.join(OUT, "day1", "customers.csv"), CUST_H, [cust_row(c) for c in customers.values()])
w(os.path.join(OUT, "day1", "accounts.csv"), ACCT_H, [acct_row(a) for a in accounts.values()])
w(os.path.join(OUT, "day1", "transactions.csv"), TXN_H, t1)


def next_day(day, tag, n_new, n_txn, email_changes, close_n, delete_n):
    """Write the delta files for one business day. Files hold only changed or new rows."""
    stamp = ts(day, 6)
    new_c, upd_c, new_a, upd_a = [], [], [], []
    for _ in range(n_new):
        cid = new_customer(ts(day, 8))
        new_c.append(customers[cid])
        for _ in range(rng.choice([1, 2])):
            aid = new_account(cid, ts(day, 8))
            new_a.append(accounts[aid])
    old = [c for c in customers.values() if c not in new_c]
    for c in rng.sample(old, email_changes):
        c["email"] = c["email"].replace("@example.test", f".{tag}@example.test")
        c["updated_at"] = stamp + timedelta(minutes=rng.randint(1, 300))
        upd_c.append(c)
    open_old = [a for a in accounts.values() if a["status"] == "OPEN" and a not in new_a]
    chosen = rng.sample(open_old, close_n + delete_n)
    for a in chosen[:close_n]:
        a["status"] = "CLOSED"
        a["updated_at"] = stamp + timedelta(minutes=rng.randint(1, 300))
        upd_a.append(a)
    deleted = [a["account_id"] for a in chosen[close_n:]]
    for aid in deleted:
        del accounts[aid]
    txns = txns_for(day, n_txn)
    p = os.path.join(OUT, tag)
    w(os.path.join(p, "customers.csv"), CUST_H, [cust_row(c) for c in new_c + upd_c])
    w(os.path.join(p, "accounts.csv"), ACCT_H, [acct_row(a) for a in new_a + upd_a])
    w(os.path.join(p, "deleted_accounts.csv"), ["account_id"], [[a] for a in deleted])
    w(os.path.join(p, "transactions.csv"), TXN_H, txns)


next_day(DAYS[2], "day2", 8, 90, 5, 3, 1)
next_day(DAYS[3], "day3", 5, 85, 4, 2, 1)

print("customers:", len(customers), "accounts:", len(accounts), "last txn id:", next_txn - 1)
