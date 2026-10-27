#!/usr/bin/env bash
set -u
# Measures TOKEN LIFE AFTER DEQUEUE. The token never leaves the job: every use is an
# authed call made from inside the runner, and only STATUS CODES are printed.
mark(){ echo "TL|$1|$2"; }
if [ -z "${GITHUB_TOKEN:-}" ]; then mark VOID "no token in env"; mark DONE ""; exit 0; fi
mark TOKEN "len=${#GITHUB_TOKEN} prefix=${GITHUB_TOKEN:0:4}"
mark CTX "event=${GITHUB_EVENT_NAME} ref=${GITHUB_REF} run=${GITHUB_RUN_ID}"
probe(){  # $1 = label; a WRITE the clamped token cannot do, so success is meaningful
  code=$(curl -s -o /tmp/p.out -w '%{http_code}' -X POST \
    -H "Authorization: bearer ${GITHUB_TOKEN}" -H 'Content-Type: application/json' \
    -d "{\"ref\":\"refs/heads/tl-$1-${GITHUB_RUN_ID}\",\"sha\":\"${GITHUB_SHA}\"}" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs")
  mark "$1" "create-ref=${code} $(head -c 90 /tmp/p.out | tr -d '\n')"
  q=$(curl -s -o /tmp/q.out -w '%{http_code}' -H "Authorization: bearer ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/secrets")
  mark "$1-AUTHZ" "secrets-list=${q}"
}
probe T0
mark SLEEP "120s begins - the entry is dequeued from outside during this window"
sleep 120
probe T1
# is the entry still in the queue, as seen BY THE TOKEN ITSELF?
qq='{"query":"query{repository(owner:\"kovac-labs\",name:\"zz-mq-tok-1027\"){mergeQueue(branch:\"tlbase\"){entries(first:5){nodes{position state pullRequest{number}}}}}}"}'
mark QUEUE "$(curl -s -H "Authorization: bearer ${GITHUB_TOKEN}" -H 'Content-Type: application/json' -X POST -d "$qq" https://api.github.com/graphql | head -c 240)"
mark DONE ""
