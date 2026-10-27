#!/usr/bin/env bash
set -uo pipefail
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "J4|VOID|GITHUB_TOKEN-EMPTY-IN-ENV - every result below is meaningless"; echo "J4|DONE"; exit 0
fi
BASE=$(cat .github/scripts/J4_BASE)
TARGET=$(cat .github/scripts/J4_TARGET_NODE)
JUMP=$(cat .github/scripts/J4_JUMP)
RSID=$(cat .github/scripts/J4_RULESET)
echo "J4|EVENT|${GITHUB_EVENT_NAME:-?}|REF|${GITHUB_REF:-?}|RUN|${GITHUB_RUN_ID:-?}"
echo "J4|ARM-PARAMS|base=${BASE}|jump=${JUMP}|target-node=${TARGET}|ruleset=${RSID}"
API=https://api.github.com/repos/kovac-labs/zz-mq-tok-1027
gq () { curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" -H 'Content-Type: application/json' -d "$1" https://api.github.com/graphql; }
rest () { curl -s -o /tmp/r -w '%{http_code}' -H "Authorization: Bearer ${GITHUB_TOKEN}" -H 'Accept: application/vnd.github+json' "$API$1"; }

# IN-RUN READ-BACK of the configuration variables, so no claim rests on a post-hoc workstation read.
S=$(rest "/rulesets/${RSID}")
echo "J4|IN-RUN-RULESET-READBACK|http=${S}|$(python3 -c "
import json
try:
  d=json.load(open('/tmp/r'))
  print('name=%s enforcement=%s bypass=%s rules=%s' % (d.get('name'),d.get('enforcement'),d.get('bypass_actors'),
        json.dumps([{r['type']:r.get('parameters')} for r in d.get('rules',[])])[:420]))
except Exception as e: print('UNREADABLE-BY-THIS-TOKEN:'+str(e)[:80])
")"
S=$(rest "/contents/.github/workflows/gate.yml?ref=${BASE}")
echo "J4|IN-RUN-BASE-GATE-BLOB|http=${S}|sha=$(python3 -c "import json;print(json.load(open('/tmp/r'))['sha'])" 2>/dev/null || echo PARSE-FAIL)"
S=$(rest "/pulls/$(cat .github/scripts/J4_SELF)/files")
echo "J4|IN-RUN-MY-OWN-DIFF|http=${S}|$(python3 -c "
import json
try: print(' '.join('%s:%s'%(f['filename'],f['status']) for f in json.load(open('/tmp/r'))))
except Exception: print('PARSE-FAIL')
")"

QUEUE="{\"query\":\"query{repository(owner:\\\"kovac-labs\\\",name:\\\"zz-mq-tok-1027\\\"){mergeQueue(branch:\\\"${BASE}\\\"){entries(first:10){nodes{position state headCommit{oid} pullRequest{number}}}}}}\"}"
rows () { gq "$QUEUE" | python3 -c "
import sys,json
d=json.load(sys.stdin)
ns=(((d.get('data') or {}).get('repository') or {}).get('mergeQueue') or {}).get('entries',{}).get('nodes') or []
print(str(len(ns))+' '+'|'.join('%s:pos%s:%s:%s'%(e['pullRequest']['number'],e['position'],e['state'],(e['headCommit'] or {}).get('oid','')[:12]) for e in ns))
" 2>/dev/null; }
refs () { curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" -H 'Accept: application/vnd.github+json' \
  "$API/git/matching-refs/heads/gh-readonly-queue/${BASE}/" | python3 -c "
import sys,json
try: print(' '.join('%s->%s'%(r['ref'].split('/')[-1][:34],r['object']['sha'][:12]) for r in json.load(sys.stdin)))
except Exception: print('PARSE-FAIL')
" 2>/dev/null; }

for i in $(seq 1 26); do
  R=$(rows); C=${R%% *}
  echo "J4|WAIT|i=${i}|entries=${R}"
  if [ "${C:-0}" -ge 2 ]; then break; fi
  sleep 10
done
echo "J4|PRE-QUEUE|$(rows)"
echo "J4|PRE-CANDIDATE-REFS|$(refs)"
M="{\"query\":\"mutation{enqueuePullRequest(input:{pullRequestId:\\\"${TARGET}\\\",jump:${JUMP}}){mergeQueueEntry{position state enqueuer{login} pullRequest{number}}}}\"}"
echo "J4|MUTATION-SENT|jump=${JUMP}"
RES=$(gq "$M")
echo "J4|ENQUEUE-RESULT|$(echo "$RES" | tr -d '\n' | head -c 460)"
sleep 25
echo "J4|POST-QUEUE-T25|$(rows)"
echo "J4|POST-CANDIDATE-REFS-T25|$(refs)"
sleep 40
echo "J4|POST-QUEUE-T65|$(rows)"
echo "J4|POST-CANDIDATE-REFS-T65|$(refs)"
echo "J4|DONE"
