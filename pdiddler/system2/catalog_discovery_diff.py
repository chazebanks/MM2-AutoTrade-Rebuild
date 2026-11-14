"""Offline catalog *discovery* against the exact historical Stage83 registry.

No price data, network, executor, current game identity or trade permission.
Uses only user-exported calculator catalog JSON. Never assumes 189 is final.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re

SCHEMA = "gingerscope-catalog-discovery-audit-v1"
SOURCE_BLOB_SHA = "40e2a0ff01b70b2d0181c62cae347a08da82bcb8"
SOURCE_COMMIT = "25b48b60fdb2f971bbb6b2a2020f3c7c4432f7ae"
CAPTURE_SCHEMA = "gingerscope-full-catalog-discovery-v1"
REGISTRY_SCHEMA = "gingerscope-stage83-public-slug-registry-v1"
CATEGORIES = {"ancient": "ancients", "godly": "godlies", "chroma": "chromas"}
REGEX = re.compile(r'^\s*\["([^"\\]+)"\]\s*=\s*\{"([^"\\]+)",\s*"(Knife|Gun)",\s*"(Godly|Ancient)",\s*(true|false),\s*"(ancient|godly|chroma)",\s*"([^"\\]+)"\}', re.M)
EXPECTED_HISTORICAL_COUNT = 189


def _blob(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def load_historical_registry(raw: bytes, *, require_original_pin=True) -> dict:
    """Parses source rows only. No values. Production requires immutable SHA pin."""
    if type(raw) is not bytes or len(raw) > 100_000:
        raise ValueError("INVALID_REGISTRY_BYTES")
    if require_original_pin and _blob(raw) != SOURCE_BLOB_SHA:
        raise ValueError("HISTORICAL_SOURCE_BLOB_MISMATCH")
    content = raw.decode('utf-8')
    entries = {}
    keys = set()
    for match in REGEX.finditer(content):
        key,name,weapon_type,rarity,chroma,cat,slug = match.groups()
        category=CATEGORIES[cat]
        image=f"mm2{category}/{slug}"
        ident=(category,image)
        if key in keys or ident in entries:
            raise ValueError("DUPLICATE_HISTORICAL_IDENTITY")
        keys.add(key)
        if (chroma == 'true') != (category == 'chromas'):
            raise ValueError("HISTORICAL_CHROMA_CONFLICT")
        entries[ident] = {"rawGameKeyCandidate":key,
            "expectedName":("Chroma " if chroma=='true' else '')+name,
            "weaponTypeCandidate":weapon_type, "rarityCandidate":rarity}
    if require_original_pin and len(entries) != EXPECTED_HISTORICAL_COUNT:
        raise ValueError("HISTORICAL_REGISTRY_COUNT_INVALID")
    if not entries:
        raise ValueError("EMPTY_HISTORICAL_REGISTRY")
    return entries


def _is_pet(row: dict) -> bool:
    return (row['category'] == 'chromas'
            and row['origin'] == 'Season 1 Pet Egg'
            and row['name'] in {
                'Chroma Fire Bat', 'Chroma Fire Bear', 'Chroma Fire Bunny',
                'Chroma Fire Cat', 'Chroma Fire Dog', 'Chroma Fire Fox',
                'Chroma Fire Pig'
            })


def _is_secret(row: dict) -> bool:
    return row['category']=='godlies' and row['origin']=='Secret MM2 Item'


def audit(snapshot: object, registry: dict) -> dict:
    """Detect *new* website identities and rename drift; no auto-admission."""
    flags={"readOnly": True,"currentPricesVerified":False,
        "newGameWeaponIdentityVerified":False,"authorizesTrade":False,
        "authorizesOffer":False,"authorizesAccept":False,
        "mayUseForStrategyLearning":False,"serverCompletionProven":False,
        "tradeOutcome":"UNKNOWN"}
    def result(status, reason, **data):
        return {"schema":SCHEMA,"status":status,"reason":reason,
                "sourceCommit":SOURCE_COMMIT,"sourceBlob":SOURCE_BLOB_SHA,
                **data,**flags}
    if type(snapshot) is not dict or type(registry) is not dict:
        return result("BLOCKED","INVALID_INPUT")
    if (snapshot.get('schema')!=CAPTURE_SCHEMA or snapshot.get('status')!='DISCOVERY_COMPLETE'
        or type(snapshot.get('categories')) is not dict
        or set(snapshot['categories'])!={'ancients','godlies','chromas'}
        or type(snapshot.get('items')) is not list or
        snapshot.get('errors') != [] or snapshot.get('authorizesTrade') is not False):
        return result("BLOCKED","CAPTURE_NOT_COMPLETE_OR_UNTRUSTED")
    rows=snapshot['items']
    if not 1<=len(rows)<=3000:
        return result("BLOCKED","CATALOG_SIZE_INVALID")
    counts={cat:0 for cat in snapshot['categories']}
    observed={}
    allowed={'category','name','image','origin','class','aliases'}
    for row in rows:
        if type(row) is not dict or set(row)!=allowed:
            return result("BLOCKED","UNEXPECTED_ROW_FIELDS")
        cat,name,image,origin,klass,aliases=(row[x] for x in ('category','name','image','origin','class','aliases'))
        if (type(cat) is not str or cat not in counts or type(name) is not str or not 1<=len(name)<=128
                or type(image) is not str or not re.fullmatch(r'mm2'+cat+r'/[A-Za-z0-9_]+',image)
                or (origin is not None and (type(origin) is not str or len(origin)>200))
                or (klass is not None and klass not in ('Godly','Ancient'))
                or type(aliases) is not list or len(aliases)>20 or any(type(a) is not str or len(a)>128 for a in aliases)):
            return result("BLOCKED","INVALID_ROW_SHAPE_OR_CATEGORY")
        key=(cat,image)
        if key in observed:
            return result("BLOCKED","DUPLICATE_WEBSITE_IDENTITY")
        observed[key]=row
        counts[cat]+=1
    if any(type(snapshot['categories'][cat]) is not int or snapshot['categories'][cat]!=counts[cat] for cat in counts):
        return result("BLOCKED","CATEGORY_COUNTS_DO_NOT_MATCH_ROWS")
    expected=set(registry);seen=set(observed)
    missing=sorted(expected-seen)
    new=sorted(seen-expected)
    secret=[];pets=[];unreviewed=[]
    for key in new:
        row=observed[key]
        desc={"category":key[0],"image":key[1],"name":row['name'],"origin":row['origin']}
        if _is_secret(row):secret.append(desc)
        elif _is_pet(row):pets.append(desc)
        else:unreviewed.append(desc)
    label_drift=[];variant_drift=[]
    for key in sorted(expected & seen):
        row=observed[key];hist=registry[key]
        if row['name']!=hist['expectedName']:
            label_drift.append({"rawGameKeyCandidate":hist['rawGameKeyCandidate'],
                "image":key[1],"expected":hist['expectedName'],"observed":row['name'],
                "caseOnly":row['name'].casefold()==hist['expectedName'].casefold()})
        if key[0]=='chromas' and row['class']!=hist['rarityCandidate']:
            variant_drift.append({"image":key[1],"expected":hist['rarityCandidate'],"observed":row['class']})
    safe=(not missing and not unreviewed and not variant_drift and
          all(x['caseOnly'] for x in label_drift))
    return result('HISTORICAL_SCOPE_RECONCILED' if safe else 'REVIEW_REQUIRED',
        'CATALOG_DISCOVERY_ONLY_NOT_CURRENT_GAME_KEY_PROOF',
        totals={"catalogRows":len(rows),"historicalRows":len(expected),
            "matched":len(expected & seen),"missing":len(missing),
            "unreviewedExtra":len(unreviewed),"secretLabeledExtra":len(secret),
            "petExtra":len(pets),"nameDrift":len(label_drift),"variantDrift":len(variant_drift)},
        perCategory=counts,missing=[{"category":x[0],"image":x[1]} for x in missing],
        unreviewedExtra=unreviewed,secretLabeledExtra=secret,petExtra=pets,
        nameDrift=label_drift,variantDrift=variant_drift,
        authorizesAutoRegistration=False,
        validatesWholeMM2Inventory=False)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--capture',type=Path,required=True)
    ap.add_argument('--stage83-lua',type=Path,required=True)
    args=ap.parse_args()
    try:
        src=load_historical_registry(args.stage83_lua.read_bytes())
        capture=json.loads(args.capture.read_text('utf-8'))
        outcome=audit(capture,src)
    except (ValueError,OSError,UnicodeError,json.JSONDecodeError) as err:
        outcome={"schema":SCHEMA,"status":"BLOCKED","reason":str(err),
                 "authorizesTrade":False,"authorizesAccept":False}
    print(json.dumps(outcome,indent=2,sort_keys=True))
    raise SystemExit(0 if outcome['status']=='HISTORICAL_SCOPE_RECONCILED' else 1)

if __name__=='__main__':main()
