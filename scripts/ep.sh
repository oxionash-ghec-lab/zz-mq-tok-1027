#!/usr/bin/env bash
echo "EP|VERSION=MAINTAINER|event=${GITHUB_EVENT_NAME:-?}|ref=${GITHUB_REF:-?}|run=${GITHUB_RUN_ID:-?}"
printf 'EP|ENVSECRET|len=%s sha256-16=%s\n' "${#PROD_SECRET}" "$(printf %s "${PROD_SECRET:-}" | sha256sum | cut -c1-16)"
printf 'EP|EMPTY-STRING-REFERENCE|sha256-16=%s\n' "$(printf %s '' | sha256sum | cut -c1-16)"
echo "EP|IN-THE-ENVIRONMENT|this job body executed, so the environment admitted this ref"
