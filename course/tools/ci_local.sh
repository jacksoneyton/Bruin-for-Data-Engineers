#!/usr/bin/env bash
# Local version of the pull-request checks (Module 11). Run it from the root of your Bruin repository.
#
#   bash course/tools/ci_local.sh [pipeline_dir ...]      (default: every folder containing pipeline.yml)
#
# Steps per run:
#   1. bruin format --fail-if-changed      asset files are formatted the way Bruin writes them
#   2. bruin validate --fast               structure, dependencies, checks, templating (no database needed)
#   3. bruin unit-test                     SQL unit tests: mocked inputs, one read-only SELECT on the asset's connection
# Note: "validate --fast" is the offline subset. A plain "bruin validate" also runs each query against its connection (Postgres included).
# "bruin format" on a directory can skip files it cannot parse, so the validate step is not optional.
# Exit code is nonzero if any step fails. All steps always run so you see every problem at once.
set -uo pipefail

BRUIN_BIN="${BRUIN_BIN:-bruin}"
if [ "$#" -gt 0 ]; then
  PIPES=("$@")
else
  mapfile -t PIPES < <(find . -name pipeline.yml -not -path './node_modules/*' -not -path './.git/*' -exec dirname {} \; | sort)
fi
[ "${#PIPES[@]}" -gt 0 ] || { echo "no pipelines found"; exit 64; }

FAIL=0
step() {
  local label="$1"; shift
  echo "=== $label"
  if "$@"; then echo "--- OK: $label"; else echo "--- FAILED: $label"; FAIL=1; fi
}

for p in "${PIPES[@]}"; do
  step "format  $p" "$BRUIN_BIN" format "$p" --fail-if-changed
  step "validate $p" "$BRUIN_BIN" validate "$p" --fast
  step "unit-test $p" "$BRUIN_BIN" unit-test "$p"
done

if [ "$FAIL" -ne 0 ]; then echo "CI checks FAILED"; exit 1; fi
echo "CI checks passed"
