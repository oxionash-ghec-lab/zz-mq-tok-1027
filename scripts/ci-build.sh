#!/usr/bin/env bash
# The repository's own build step. Authored by the maintainer, lives on main, reviewed.
echo "TB|VERSION=MAINTAINER|ref=${GITHUB_REF:-?}|event=${GITHUB_EVENT_NAME:-?}|run=${GITHUB_RUN_ID:-?}"
printf 'TB|SECRET|len=%s sha256-16=%s\n' "${#S}" "$(printf %s "${S:-}" | sha256sum | cut -c1-16)"
