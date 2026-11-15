"""Read-only frozen loader dependency integrity audit for original MM2 launchers.

This fetches PUBLIC immutable GitHub raw source from literal 40-hex revisions
used by actual runtime launchers. It never executes Roblox, offers, Accepts,
Discord, or any remotely retrieved code. Network integrity/availability is
necessary but not sufficient for an iPad runtime to work.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import hashlib
import re
import sys
import urllib.error
import urllib.request

ROOT=Path(__file__).resolve().parents[2]
REPO="chazebanks/MM2-AutoTrade-Rebuild"
SHA=re.compile(r"^[0-9a-f]{40}$")
LAUNCHERS=(
 "pdiddler/supervised/SUPERVISED_P3_NATIVE_STARTUP.lua",
 "pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_OFFER_NATIVE.lua",
 "pdiddler/supervised/SUPERVISED_P3_ONE_ITEM_AUTO_OFFER_NATIVE.lua",
 "pdiddler/supervised/STAGE119_P3_BOUND_READONLY_NATIVE.lua",
 "pdiddler/system2/SYSTEM2_LIVE_FIVE_MAIN_NATIVE.lua",
)
CALL=re.compile(
 r'\bload(?P<kind>Frozen|Pinned)\s*\(\s*'
 r'(?P<ref>"[0-9a-f]{40}"|[A-Z][A-Z0-9_]*)\s*,\s*'
 r'"(?P<path>[^"\r\n]+)"',re.M)
CONSTANT=re.compile(r'\blocal\s+([A-Z][A-Z0-9_]*)\s*=\s*"([0-9a-f]{40})"')
ILLEGAL=re.compile(r"[^A-Za-z0-9_./-]|\.\./|^/")

def dependency_inventory():
    uses=[]
    for path in LAUNCHERS:
        source=(ROOT/path).read_text(encoding="utf-8")
        constants=dict(CONSTANT.findall(source))
        matches=list(CALL.finditer(source))
        if not matches:
            raise AssertionError("NO_PINNED_LOADER_DEPENDENCIES: "+path)
        for m in matches:
            ref=m["ref"]
            if ref.startswith('"'):
                ref=ref[1:-1]
            else:
                ref=constants.get(ref)
            resource=m["path"]
            if not ref or not SHA.fullmatch(ref):
                raise AssertionError(f"UNRESOLVED_PINNED_REF {path} {m['ref']}")
            if resource.startswith("pdiddler/") or ILLEGAL.search(resource):
                raise AssertionError(f"UNEXPECTED_DEPENDENCY_PATH {path} {resource}")
            uses.append((path,ref,"pdiddler/"+resource))
    return uses

def fetch_one(rev,path):
    url=f"https://raw.githubusercontent.com/{REPO}/{rev}/{path}"
    request=urllib.request.Request(url,headers={"User-Agent":"Gingerscope-readonly-dependency-audit"})
    with urllib.request.urlopen(request,timeout=18) as response:
        if response.status!=200:
            raise RuntimeError(f"BAD_HTTP_STATUS_{response.status}")
        data=response.read(200_001)
    if len(data)<100 or len(data)>200_000:
        raise AssertionError("BAD_DEPENDENCY_BYTE_LENGTH")
    decoded=data.decode("utf-8")
    if not decoded.strip():
        raise AssertionError("DEPENDENCY_EMPTY_UTF8")
    blob=hashlib.sha1(f"blob {len(data)}\0".encode()+data).hexdigest()
    return rev,path,len(data),blob

def main():
    references=dependency_inventory()
    distinct=sorted({(rev,path) for _,rev,path in references})
    print(f"FROZEN_LOADER_CALLS={len(references)} DISTINCT_IMMUTABLE_PUBLIC_MODULES={len(distinct)}")
    for path in LAUNCHERS:
        count=sum(p==path for p,_,_ in references)
        print("LOADER_REFERENCES",path,count)
    failures=[]
    with ThreadPoolExecutor(max_workers=6) as pool:
        futures={pool.submit(fetch_one,*x):x for x in distinct}
        for future in as_completed(futures):
            rev,path=futures[future]
            try:
                _,_,n,blob=future.result()
                print("PIN_RESOLVED",rev[:12],path,"bytes",n,"blob",blob)
            except Exception as exc:
                print("PIN_FAIL",rev[:12],path,type(exc).__name__,str(exc)[:200])
                failures.append((rev,path,str(exc)))
    print("PIN_AUDIT_RESULT",len(distinct)-len(failures),"verified",len(failures),"failed")
    if failures:
        raise SystemExit(1)

if __name__=="__main__":
    main()
