"""System2 read-only market research lookup and hypothetical portfolio valuation.

Consumes immutable original SHA256-pinned calculator export via existing adapter.
Never a verified live price, observed MM2 inventory, offer plan, settlement or accept.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path

from pdiddler.system2.operator_capture_adapter import ingest, AUTHORITY_DENIED, SCHEMA as INPUT_SCHEMA

SCHEMA='gingerscope-system2-market-research-reader-v1'
TARGET_KEY='Gingerscope'


def _report(status,reason,**fields):
    return {'schema':SCHEMA,'status':status,'reason':reason,'sourceEditionAuthenticated':False,
            'liveInventoryVerified':False,'measuredLiquidityVerified':False,
            'canProposeOrExecuteTrade':False,'targetOutgoingProtected':True,
            **fields, **AUTHORITY_DENIED}


def _index(mapped):
    if not isinstance(mapped,dict) or mapped.get('schema')!=INPUT_SCHEMA or mapped.get('status')!='OFFLINE_CROSSWALK_READY':
        raise ValueError('MAPPED_SOURCE_UNVERIFIED')
    if len(mapped.get('records',[]))!=189 or mapped.get('publisherVersion') is not None:
        raise ValueError('UNEXPECTED_MAPPED_SOURCE_VERSION')
    if any(mapped.get(k) != v for k,v in AUTHORITY_DENIED.items()):
        raise ValueError('SOURCE_AUTHORITY_CONTRACT_VIOLATION')
    known={}
    for row in mapped['records']:
        key=row.get('rawGameKeyCandidate')
        if (not isinstance(key,str) or not key or key in known
                or not isinstance(row.get('decimalValue'),int)
                or row.get('decimalValue')<0):
            raise ValueError('DUPLICATE_OR_INVALID_MAPPED_KEY')
        known[key]=row
    if TARGET_KEY not in known or known[TARGET_KEY]['image']!='mm2ancients/Gingerscope':
        raise ValueError('TARGET_GINGERSCOPE_MISSING_OR_CHANGED')
    return known


def _item(row):
    # From existing source adapter: never recalculate or estimate published numbers.
    return {'rawGameKeyCandidate':row['rawGameKeyCandidate'],
            'name':row['name'],'image':row['image'],'category':row['category'],
            'gameItemTypeCandidate':row['gameItemTypeCandidate'],
            'rarityCandidate':row['gameRarityCandidate'],
            'chromaCandidate':row['chromaCandidate'],
            'listedValue':row['decimalValue'],
            'display':row['valueDisplay'],
            'rangeLow':row['rangeLow'],'rangeHigh':row['rangeHigh'],
            'previousListedValue':row['previousDecimalValue'],
            'demand':row['demand'],'stability':row['stability'],
            'observedAt':row['observedAt'],
            'outgoingProtected':row['rawGameKeyCandidate']==TARGET_KEY}


def lookup_mapped(mapped, raw_key):
    """Only exact historical raw key candidates; not fuzzy website display labels."""
    try:
        idx=_index(mapped)
        if type(raw_key) is not str or raw_key not in idx:
            raise ValueError('UNKNOWN_EXACT_HISTORICAL_GAME_KEY')
        return _report('RESEARCH_LOOKUP_READY','HISTORICAL_KEY_CANDIDATE_ONLY',
                       item=_item(idx[raw_key]),
                       sourceSha256=mapped['sourceExportSha256'],
                       publisherVersion=mapped['publisherVersion'])
    except (ValueError,TypeError,KeyError) as exc:
        return _report('BLOCKED',str(exc)[:140])


def portfolio_mapped(mapped,inventory):
    """Analyze hypothetical quantities, NOT current account inventory or P4 slots.

    inventory = [{"rawGameKey":"...", "quantity":N}]. Four offer slots are
    deliberately *not* enforced on a portfolio; this never constructs offers.
    """
    try:
        idx=_index(mapped)
        if type(inventory) is not list or not 1<=len(inventory)<=189:
            raise ValueError('PORTFOLIO_ROWS_INVALID')
        used=set();items=[];total=low=high=0
        exposure={};counts={'ancients':0,'godlies':0,'chromas':0}
        for request in inventory:
            if (type(request) is not dict or set(request)!={'rawGameKey','quantity'}
                or type(request['rawGameKey']) is not str
                or type(request['quantity']) is not int
                or not 1<=request['quantity']<=10000):
                raise ValueError('INVALID_PORTFOLIO_QUANTITY_OR_SHAPE')
            key=request['rawGameKey']
            if key in used:raise ValueError('DUPLICATE_PORTFOLIO_KEY')
            used.add(key)
            if key not in idx:raise ValueError('UNKNOWN_EXACT_HISTORICAL_GAME_KEY')
            row=idx[key];qty=request['quantity']
            subtotal=row['decimalValue']*qty
            total+=subtotal;low+=row['rangeLow']*qty;high+=row['rangeHigh']*qty
            exposure[row['stability']]=exposure.get(row['stability'],0)+subtotal
            counts[row['category']]+=qty
            items.append({**_item(row),'quantity':qty,
                          'listedSubtotal':subtotal,'rangeSubtotalLow':row['rangeLow']*qty,
                          'rangeSubtotalHigh':row['rangeHigh']*qty})
        target=idx[TARGET_KEY]['decimalValue']
        return _report('HYPOTHETICAL_PORTFOLIO_READY',
                       'LISTED_VALUE_ONLY_NOT_EXECUTABLE_TRADE_OR_PARTNER_APPEAL',
                       sourceSha256=mapped['sourceExportSha256'],
                       totalListedValue=total,totalRangeLow=low,totalRangeHigh=high,
                       targetGingerscopeListedValue=target,
                       listedValueGap=max(0,target-total),
                       listedValueSufficient=total>=target,
                       # Total listed portfolio value does not mean one 4-slot offer is possible.
                       fourSlotTradeFeasibility='UNPROVEN',
                       partnerAppeal='UNKNOWN',
                       actualRetradeLiquidity='UNKNOWN',
                       stabilityExposureListedValue=dict(sorted(exposure.items())),
                       itemCounts=counts,
                       rows=sorted(items,key=lambda x:x['rawGameKeyCandidate']))
    except (ValueError,TypeError,KeyError) as exc:
        return _report('BLOCKED',str(exc)[:140])


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--export',type=Path,required=True)
    ap.add_argument('--stage83-lua',type=Path,required=True)
    group=ap.add_mutually_exclusive_group(required=True)
    group.add_argument('--raw-key')
    group.add_argument('--inventory-json',type=Path)
    args=ap.parse_args()
    try:
        source=ingest(args.export.read_bytes(),args.stage83_lua.read_bytes())
        result=(lookup_mapped(source,args.raw_key) if args.raw_key is not None
                else portfolio_mapped(source,json.loads(args.inventory_json.read_text('utf-8'))))
    except (OSError,ValueError,TypeError,json.JSONDecodeError) as exc:
        result=_report('BLOCKED','INVALID_OR_MISSING_PINNED_SOURCE:'+str(exc)[:110])
    print(json.dumps(result,indent=2))
    return 0 if result['status']!='BLOCKED' else 1

if __name__=='__main__':raise SystemExit(main())
