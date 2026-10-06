#!/usr/bin/env bash
# Run a Bruin command, keep its log, and raise an alert when it fails (Module 11).
#
#   bash tools/run_and_alert.sh <job_name> -- <bruin arguments...>
#   example: bash tools/run_and_alert.sh nightly_lakota -- run lakota --start-date 2026-01-04 --end-date 2026-01-04
#
# Why this exists: Bruin's notifications are a Bruin Cloud feature, and an asset cannot run
# "on failure" because assets downstream of a failed asset are skipped. The only place that
# sees the failure of the whole run is the process that started it.
#
# On failure the script:
#   1. appends a line to $ALERT_DIR/alerts.log   (default: logs/alerts)
#   2. posts a JSON message {"text": "..."} to $ALERT_WEBHOOK_URL when it is set
# It always exits with Bruin's own exit code, so the scheduler also records the failure.
#
# Settings: ALERT_DIR, ALERT_WEBHOOK_URL, ALERT_TAIL_LINES (default 15), BRUIN_BIN (default bruin)
set -uo pipefail

JOB="${1:?usage: run_and_alert.sh <job_name> -- <bruin arguments...>}"
shift
[ "${1:-}" = "--" ] && shift
[ "$#" -gt 0 ] || { echo "no bruin arguments given" >&2; exit 64; }
[[ "$JOB" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "bad job name" >&2; exit 64; }

BRUIN_BIN="${BRUIN_BIN:-bruin}"
ALERT_DIR="${ALERT_DIR:-logs/alerts}"
TAIL_LINES="${ALERT_TAIL_LINES:-15}"
mkdir -p "$ALERT_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG="$ALERT_DIR/${JOB}_${STAMP}.log"

"$BRUIN_BIN" "$@" 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}

if [ "$RC" -eq 0 ]; then
  echo "$(date '+%F %T') job=$JOB status=OK" >> "$ALERT_DIR/history.log"
  exit 0
fi

HOST="$(hostname)"
TAIL="$(tail -n "$TAIL_LINES" "$LOG" | tr -d '\r')"
MSG="Bruin job $JOB FAILED (exit $RC) on $HOST at $(date '+%F %T'). Log: $LOG"
echo "$(date '+%F %T') job=$JOB status=FAILED rc=$RC log=$LOG" >> "$ALERT_DIR/history.log"
echo "$MSG" >> "$ALERT_DIR/alerts.log"

if [ -n "${ALERT_WEBHOOK_URL:-}" ]; then
  # Build the JSON with python so quotes and newlines in the log tail are escaped correctly.
  PAYLOAD="$(MSG="$MSG" TAIL="$TAIL" python3 -c 'import json,os; print(json.dumps({"text": os.environ["MSG"] + "\n" + os.environ["TAIL"]}))' 2>/dev/null \
    || MSG="$MSG" TAIL="$TAIL" python -c 'import json,os; print(json.dumps({"text": os.environ["MSG"] + "\n" + os.environ["TAIL"]}))')"
  if [ -n "$PAYLOAD" ]; then
    curl -sS -m 20 -X POST -H 'Content-Type: application/json' -d "$PAYLOAD" "$ALERT_WEBHOOK_URL" >/dev/null \
      || echo "$(date '+%F %T') job=$JOB webhook delivery failed" >> "$ALERT_DIR/alerts.log"
  fi
fi

exit "$RC"
