#!/usr/bin/env bash
#
# Run a headless Locust load test against the Task Manager API.
#
# Usage:
#   ./run-load-test.sh [HOST] [USERS] [SPAWN_RATE] [DURATION]
#
# Examples:
#   ./run-load-test.sh                                  # defaults
#   ./run-load-test.sh http://localhost:3000 200 10 5m  # stress test for HPA demo

set -euo pipefail

HOST="${1:-http://localhost:3000}"
USERS="${2:-50}"
SPAWN_RATE="${3:-5}"
DURATION="${4:-2m}"
REPORT="report_$(date +%Y%m%d_%H%M%S).html"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCUSTFILE="${SCRIPT_DIR}/locustfile.py"

echo "============================================"
echo " Task Manager API - Load Test"
echo "============================================"
echo " Host:        ${HOST}"
echo " Users:       ${USERS}"
echo " Spawn rate:  ${SPAWN_RATE}/s"
echo " Duration:    ${DURATION}"
echo " Report:      ${REPORT}"
echo "============================================"
echo ""

locust \
  -f "${LOCUSTFILE}" \
  --host="${HOST}" \
  --users "${USERS}" \
  --spawn-rate "${SPAWN_RATE}" \
  --run-time "${DURATION}" \
  --headless \
  --html "${REPORT}"

echo ""
echo "Done. HTML report saved to ${REPORT}"
