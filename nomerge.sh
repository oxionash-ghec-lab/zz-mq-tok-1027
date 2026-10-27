#!/bin/bash
# NEGATIVE CONTROL: identical to merge.sh with the two FORGE steps REMOVED.
# If protection is what the forge defeats, this must be REFUSED.
API="https://api.github.com"
H=(-H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json")
R="$GITHUB_REPOSITORY"
echo "NEG|CTX|event=$GITHUB_EVENT_NAME ref=$GITHUB_REF"
curl -s "${H[@]}" "$API/repos/$R/pulls?state=open&base=release&per_page=20" > /tmp/prs
read -r PRN PRS <<<"$(python3 -c "
import json
for p in json.load(open('/tmp/prs')):
    print(p['number'], p['head']['sha']); break
")"
echo "NEG|TARGET|pr=$PRN head=$PRS"
if [ -n "$PRN" ]; then
  code=$(curl -s -o /tmp/o -w '%{http_code}' -X PUT "${H[@]}" -d '{"merge_method":"merge"}' "$API/repos/$R/pulls/$PRN/merge")
  echo "NEG|$code|MERGE-WITHOUT-FORGING|$(head -c 260 /tmp/o | tr -d '\n')"
fi
echo "NEG|DONE|nomerge.sh completed unconditionally"
