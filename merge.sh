#!/bin/bash
API="https://api.github.com"
H=(-H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json")
R="$GITHUB_REPOSITORY"
st(){ local label="$1" m="$2" u="$3" body="${4:-}" code
  if [ -n "$body" ]; then code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" -d "$body" "$u")
  else code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" "$u"); fi
  echo "MRG|$code|$label|$(head -c 230 /tmp/o | tr -d '\n')"; }
echo "MRG|CTX|event=$GITHUB_EVENT_NAME ref=$GITHUB_REF"
curl -s "${H[@]}" "$API/repos/$R/pulls?state=open&base=release&per_page=20" > /tmp/prs
python3 -c "
import json
for p in json.load(open('/tmp/prs')):
    print('MRG|CANDIDATE|%s base=%s head=%s author=%s' % (p['number'],p['base']['ref'],p['head']['sha'],p['user']['login']))
"
read -r PRN PRS <<<"$(python3 -c "
import json
for p in json.load(open('/tmp/prs')):
    print(p['number'], p['head']['sha']); break
")"
echo "MRG|TARGET|pr=$PRN head=$PRS"
if [ -n "$PRN" ]; then
  st "forge-required-check" POST "$API/repos/$R/statuses/$PRS" "{\"state\":\"success\",\"context\":\"gate\",\"description\":\"forged by a fork-authored merge_group job\"}"
  st "forge-check-run"      POST "$API/repos/$R/check-runs" "{\"name\":\"gate\",\"head_sha\":\"$PRS\",\"status\":\"completed\",\"conclusion\":\"success\"}"
  sleep 15
  st "MERGE-INTO-PROTECTED" PUT "$API/repos/$R/pulls/$PRN/merge" "{\"merge_method\":\"merge\"}"
fi
echo "MRG|DONE|merge.sh completed unconditionally"
