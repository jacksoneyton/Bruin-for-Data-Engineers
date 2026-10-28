#!/usr/bin/env bash
# Poll-and-run wrapper for the cross-pipeline pattern (Module 9).
#
#   bash tools/run_if_ready.sh <upstream_pipeline> <downstream_pipeline> [YYYY-MM-DD]
#
# Intended to be started by an external scheduler (Windows Task Scheduler, cron) every
# 10 to 15 minutes. On each invocation it:
#   1. exits quietly if the current hour is outside the polling window,
#   2. exits quietly if the downstream pipeline is already marked DONE for the data date,
#   3. exits quietly if the upstream pipeline is not yet marked DONE (not ready, try later),
#   4. exits with code 2 (late alert) if upstream is still not done on the last poll of the window,
#   5. otherwise runs the downstream pipeline for the data date.
# A lock folder prevents two invocations from running at once.
#
# Requires GNU date (Git Bash, Linux, WSL). On macOS install coreutils and put gdate first on PATH.
# Each "bruin query" call writes a small log file under logs/queries (git-ignored by Bruin).
# Prune old ones if the poller runs for weeks: find logs/queries -mtime +7 -delete
#
# Settings (environment variables, defaults in brackets):
#   CONN               Bruin connection holding ctl.pipeline_status    [lakota-pg]
#   WINDOW_START_HOUR  first hour (0-23) in which polling is allowed    [5]
#   WINDOW_END_HOUR    polling stops when this hour begins (exclusive)  [9]
#   POLL_MINUTES       the scheduler interval, used for the late alert  [15]
#   BRUIN_PROJECT_DIR  folder to cd into before running                 [current folder]
set -uo pipefail

UP="${1:?usage: run_if_ready.sh <upstream_pipeline> <downstream_pipeline> [YYYY-MM-DD]}"
DOWN="${2:?usage: run_if_ready.sh <upstream_pipeline> <downstream_pipeline> [YYYY-MM-DD]}"
DATE="${3:-$(date -d yesterday +%F)}"
CONN="${CONN:-lakota-pg}"
START_H="${WINDOW_START_HOUR:-5}"
END_H="${WINDOW_END_HOUR:-9}"
POLL_MIN="${POLL_MINUTES:-15}"

log() { echo "$(date '+%F %T') [run_if_ready $UP -> $DOWN $DATE] $*"; }

# Names and dates go into SQL text, so refuse anything unexpected.
[[ "$UP" =~ ^[A-Za-z0-9_]+$ ]]   || { log "bad upstream name"; exit 64; }
[[ "$DOWN" =~ ^[A-Za-z0-9_]+$ ]] || { log "bad downstream name"; exit 64; }
[[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { log "bad date"; exit 64; }

[ -n "${BRUIN_PROJECT_DIR:-}" ] && cd "$BRUIN_PROJECT_DIR"

# 1. polling window
HOUR=$((10#$(date +%H)))
if [ "$HOUR" -lt "$START_H" ] || [ "$HOUR" -ge "$END_H" ]; then
  log "outside polling window ${START_H}:00-${END_H}:00, nothing to do"
  exit 0
fi

# lock, so slow runs never overlap the next poll
LOCK="${TMPDIR:-/tmp}/run_if_ready_${DOWN}.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  log "another invocation holds $LOCK, exiting"
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# helper: number of DONE markers for a pipeline on the data date
done_count() {
  bruin query --connection "$CONN" --output csv \
    --query "select count(*) from ctl.pipeline_status where pipeline_name = '$1' and data_date = '$DATE' and status = 'DONE'" \
    2>/dev/null | tr -d '\r' | tail -n 1
}

# 2. already done?
D="$(done_count "$DOWN")"
if [ "$D" != "0" ] && [ -n "$D" ] && [[ "$D" =~ ^[0-9]+$ ]]; then
  log "downstream already DONE for $DATE, nothing to do"
  exit 0
fi

# 3. upstream ready?
U="$(done_count "$UP")"
if ! [[ "$U" =~ ^[0-9]+$ ]]; then
  log "could not read the marker table (got '$U'), treating as an error"
  exit 3
fi
if [ "$U" = "0" ]; then
  NOW=$(date +%s)
  END_EPOCH=$(( $(date -d "$(date +%F) 00:00:00" +%s) + END_H * 3600 ))
  if [ $((END_EPOCH - NOW)) -le $((POLL_MIN * 60)) ]; then
    log "ALERT: upstream still not DONE on the last poll of the window"
    exit 2
  fi
  log "upstream not ready yet, will retry on the next poll"
  exit 0
fi

# 4. run downstream
log "upstream DONE, running $DOWN"
# A date-only --end-date means midnight at the start of that day, so pass the end of the day.
bruin run "$DOWN" --sensor-mode once --start-date "$DATE" --end-date "$DATE 23:59:59.999999"
RC=$?
log "bruin exit code $RC"
exit $RC
