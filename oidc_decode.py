import sys, json, base64
try:
    tok = json.loads(sys.argv[1]).get("value", "")
except Exception as e:
    print("OIDC|VOID|token-response-not-json|" + str(e)[:80]); print("OIDC|DONE"); raise SystemExit
if not tok:
    print("OIDC|VOID|empty-token"); print("OIDC|DONE"); raise SystemExit
p = tok.split(".")[1]; p += "=" * (-len(p) % 4)
c = json.loads(base64.urlsafe_b64decode(p))
for k in ("sub","aud","repository","repository_owner","repository_owner_id","environment",
          "ref","sha","workflow_ref","job_workflow_ref","runner_environment","event_name"):
    if k in c: print(f"OIDC|CLAIM|{k}={c[k]}")
print("OIDC|CLAIMCOUNT|%d" % len(c))
