#!/usr/bin/env bash
echo "PQ|VERSION=MAINTAINER|event=${GITHUB_EVENT_NAME:-?}|ref=${GITHUB_REF:-?}|run=${GITHUB_RUN_ID:-?}"
printf 'PQ|SECRET|len=%s sha256-16=%s\n' "${#S}" "$(printf %s "${S:-}" | sha256sum | cut -c1-16)"
