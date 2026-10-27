#!/bin/bash
API="https://api.github.com"
H=(-H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json")
R="$GITHUB_REPOSITORY"
echo "RVW|CTX|event=$GITHUB_EVENT_NAME ref=$GITHUB_REF sha=$GITHUB_SHA actor=$GITHUB_ACTOR"
echo "RVW|MARKER|$(cat rvw-marker.txt 2>/dev/null || echo MISSING)"
echo "RVW|SECRET|len=${#S}|sha256=$(printf %s "$S" | sha256sum | cut -d' ' -f1)"
code=$(curl -s -o /tmp/o -w '%{http_code}' -X POST "${H[@]}" -d "{\"ref\":\"refs/heads/rvw-$GITHUB_RUN_ID\",\"sha\":\"$GITHUB_SHA\"}" "$API/repos/$R/git/refs")
echo "RVW|WRITE-TEST|$code|$(head -c 150 /tmp/o | tr -d '\n')"
echo "RVW|DONE|rvw.sh completed unconditionally"
