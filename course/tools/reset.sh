#!/usr/bin/env bash
# Reset helpers for the Lakota Bank course.
#
#   bash tools/reset.sh source N     Recreate the source system (src_core in $PGURL_SRC)
#                                    and apply business days 1..N (N is 1, 2 or 3).
#   bash tools/reset.sh warehouse    Drop the course schemas in the warehouse database ($PGURL).
#
# Safety: both commands refuse to run unless the connected database has the expected
# name (bruin_course for the warehouse, bruin_course_src for the source). The warehouse
# command only drops the schemas listed below and the jane_* prefix schemas of Module 10,
# never public. The dev database from Module 10 (bruin_course_dev) is not touched.
set -euo pipefail

DATA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../data" && pwd)"
WAREHOUSE_DB="${COURSE_DB_NAME:-bruin_course}"
SOURCE_DB="${COURSE_SRC_DB_NAME:-bruin_course_src}"
SCHEMAS="smoke ref landing staging mart hist ctl dq ops lakota_reports risk"

need() { [ -n "${!1:-}" ] || { echo "ERROR: $1 is not set"; exit 1; }; }
dbname() { psql "$1" -Atc "select current_database()"; }

case "${1:-}" in
  source)
    need PGURL_SRC
    n="${2:-1}"
    case "$n" in 1|2|3) ;; *) echo "ERROR: N must be 1, 2 or 3"; exit 1;; esac
    db="$(dbname "$PGURL_SRC")"
    [ "$db" = "$SOURCE_DB" ] || { echo "ERROR: PGURL_SRC points at '$db', expected '$SOURCE_DB'. Refusing."; exit 1; }
    cd "$DATA_DIR"
    psql "$PGURL_SRC" -q -f sql/01_source_init.sql
    [ "$n" -ge 2 ] && psql "$PGURL_SRC" -q -f sql/02_source_day2.sql
    [ "$n" -ge 3 ] && psql "$PGURL_SRC" -q -f sql/03_source_day3.sql
    echo "Source reset to day $n."
    psql "$PGURL_SRC" -c "select 'customers' t, count(*) from src_core.customers union all select 'accounts', count(*) from src_core.accounts union all select 'transactions', count(*) from src_core.transactions"
    ;;
  warehouse)
    need PGURL
    db="$(dbname "$PGURL")"
    [ "$db" = "$WAREHOUSE_DB" ] || { echo "ERROR: PGURL points at '$db', expected '$WAREHOUSE_DB'. Refusing."; exit 1; }
    for s in $SCHEMAS; do
      psql "$PGURL" -q -c "drop schema if exists $s cascade"
    done
    # Schema-prefix environments from Module 10 (jane_*) live in this database too.
    for s in $(psql "$PGURL" -Atc "select nspname from pg_namespace where nspname like 'jane\_%'"); do
      psql "$PGURL" -q -c "drop schema if exists \"$s\" cascade"
    done
    echo "Dropped course schemas in $db: $SCHEMAS and any jane_* schemas"
    ;;
  *)
    sed -n '2,11p' "$0"
    exit 1
    ;;
esac
