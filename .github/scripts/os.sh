#!/usr/bin/env bash
set -uo pipefail
echo "OS|EVENT|${GITHUB_EVENT_NAME:-?}|REF|${GITHUB_REF:-?}|RUN|${GITHUB_RUN_ID:-?}"
h () { printf '%s' "${1:-}" | sha256sum | cut -c1-16; }
row () { printf 'OS|SECRET|%-22s|len=%-3s|sha256-16=%s\n' "$1" "${#2}" "$(h "$2")"; }
row ORG-selected-THIS-repo      "${ORGSEC:-}"
row ORG-selected-OTHER-repo     "${ORGSEC_EXCLUDED:-}"
row REPO-level-positive-control "${REPOSEC:-}"
row NONEXISTENT-negative-ctl    "${ABSENT:-}"
echo "OS|EMPTY-STRING-REFERENCE|len=0|sha256-16=$(h '')"
echo "OS|DONE"
