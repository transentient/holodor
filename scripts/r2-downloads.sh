#!/usr/bin/env bash
# r2-downloads.sh — how many times each published image was fetched from the R2 bucket.
#
# Reads the Cloudflare GraphQL Analytics API (needs a token with Account Analytics: Read in
# ~/.config/cloudflare/analytics.token; the S3 keys cannot query analytics). Two numbers:
#   * GetObject requests per object (r2OperationsAdaptiveGroups, objectName dimension) — a browser
#     fetches a 3 GB file as many range requests, so this OVERSTATES downloads.
#   * bytes downloaded per day for the bucket (bandwidth dataset) / image size = full-download
#     equivalents — the honest estimate.
# Usage: scripts/r2-downloads.sh [DAYS]   (default 30; R2 analytics keep ~90 days)
set -euo pipefail
export DAYS="${1:-30}"
export ACCOUNT="${CF_ACCOUNT_ID:-48a83434edd8dcc90118c8d32b3113be}"   # from the R2 endpoint hostname
export BUCKET="${R2_BUCKET:-holodor-images}"
TOKEN_FILE="${CF_ANALYTICS_TOKEN_FILE:-$HOME/.config/cloudflare/analytics.token}"
[ -r "${TOKEN_FILE}" ] || { echo "no token file at ${TOKEN_FILE}" >&2; exit 1; }
export CF_TOKEN="$(tr -d '[:space:]' < "${TOKEN_FILE}")"
exec python3 - <<'PY'
import json, os, sys, urllib.request, datetime as dt
acct, bucket, days = os.environ["ACCOUNT"], os.environ["BUCKET"], int(os.environ["DAYS"])
now = dt.datetime.now(dt.timezone.utc)
since = (now - dt.timedelta(days=days)).strftime("%Y-%m-%dT00:00:00Z")
until = now.strftime("%Y-%m-%dT%H:%M:%SZ")
IMAGE_GB = 3.35

def gql(q):
    req = urllib.request.Request("https://api.cloudflare.com/client/v4/graphql",
        data=json.dumps({"query": q}).encode(),
        headers={"Authorization": "Bearer " + os.environ["CF_TOKEN"], "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.load(r)
    if d.get("errors"):
        print("ERROR:", json.dumps(d["errors"], indent=1)[:1500]); return None
    return d["data"]["viewer"]["accounts"][0]

print(f"== GetObject requests per object, {bucket}, last {days} days (range requests inflate this)")
a = gql(f'''{{ viewer {{ accounts(filter: {{accountTag: "{acct}"}}) {{
  r2OperationsAdaptiveGroups(limit: 200, orderBy: [sum_requests_DESC],
    filter: {{datetime_geq: "{since}", datetime_leq: "{until}", bucketName: "{bucket}", actionType: "GetObject"}}) {{
    dimensions {{ objectName }} sum {{ requests responseObjectSize }} }} }} }} }}''')
if a:
    # the bucket's custom domain is scanned by bots (.env, phpinfo.php ...); keep our files only
    rows = [r for r in a["r2OperationsAdaptiveGroups"] if r["dimensions"]["objectName"].endswith((".img.zst", ".sha256"))]
    if not rows: print("  (no GetObject rows in range)")
    for r in rows:
        print(f'  {r["sum"]["requests"]:>8}  {(r["sum"].get("responseObjectSize") or 0)/1e9:8.2f} GB  {r["dimensions"]["objectName"]}')

print(f"\n== bytes downloaded per day, {bucket} (/{IMAGE_GB} GB per image = full-download equivalents)")
a = gql(f'''{{ viewer {{ accounts(filter: {{accountTag: "{acct}"}}) {{
  r2BandwidthUsageAdaptiveGroups(limit: 2000, orderBy: [datetimeHour_ASC],
    filter: {{datetimeHour_geq: "{since}", datetimeHour_leq: "{until}", bucketName: "{bucket}"}}) {{
    dimensions {{ datetimeHour }} sum {{ bytesDownload }} }} }} }} }}''')
if a:
    per = {}
    for r in a["r2BandwidthUsageAdaptiveGroups"]:
        per[r["dimensions"]["datetimeHour"][:10]] = per.get(r["dimensions"]["datetimeHour"][:10], 0) + (r["sum"]["bytesDownload"] or 0)
    tot = 0
    for d in sorted(per):
        tot += per[d]; print(f'  {d}  {per[d]/1e9:8.2f} GB  {per[d]/(IMAGE_GB*1e9):6.1f} downloads')
    print(f'  {"total":10}  {tot/1e9:8.2f} GB  {tot/(IMAGE_GB*1e9):6.1f} downloads')
PY
