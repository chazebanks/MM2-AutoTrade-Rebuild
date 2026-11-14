"""Corroborate one pinned operator export against three official page HTML captures.

Research-only, independent presentation parity. This is NOT source-authenticated live
price authority and does not turn caller-supplied HTML into a trusted network receipt.
Do not use to automate Roblox offers/acceptance/Discord, or restamp a stale export.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from zoneinfo import ZoneInfo

from pdiddler.system2.operator_capture_adapter import ingest, AUTHORITY_DENIED

CATS=('ancients','godlies','chromas')
CANONICAL={c:f'https://supremevalues.com/mm2/{c}' for c in CATS}
SCHEMA='gingerscope-system2-three-page-publisher-parity-v1'
PUBLISHER_PATTERN=re.compile(
    r'Values\s+Last\s+Updated\s*-\s*(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})(?:st|nd|rd|th),\s*(20\d\d)\s+at\s+(\d{1,2}):(\d\d)\s*(AM|PM)',re.I)
ALLOW_EXTRA={
 ('godlies','mm2godlies/Batwing'),
 ('godlies','mm2godlies/Black_Luger'),
 ('chromas','mm2chromas/CBat'),('chromas','mm2chromas/CBear'),
 ('chromas','mm2chromas/CBunny'),('chromas','mm2chromas/CCat'),
 ('chromas','mm2chromas/CDog'),('chromas','mm2chromas/CFox'),
 ('chromas','mm2chromas/CPig'),
}
# The website's "Nik's Scythe" is a priceless special item outside the
# historical 189 numeric weapons; never manufacture a numeric value for it.


def _blocked(reason):
    return {'schema':SCHEMA,'status':'BLOCKED','reason':reason,
            'confirmedPublisherUtc':None,'sourcePageParity':False,
            **AUTHORITY_DENIED}


def _parse_publisher_timestamp(text):
    hits=PUBLISHER_PATTERN.findall(re.sub(r'\s+',' ',text))
    if len(hits)!=1:
        raise ValueError('PUBLISHER_TIMESTAMP_NOT_UNIQUE')
    month,day,year,hour,minute,ampm=hits[0]
    naive=datetime.strptime(f'{month} {int(day)} {year} {int(hour)}:{minute} {ampm.upper()}', '%B %d %Y %I:%M %p')
    return naive.replace(tzinfo=ZoneInfo('America/New_York')).astimezone(timezone.utc)


class _WebsiteCards(HTMLParser):
    """Extract source-authored itemcolumn attributes from canonical HTML."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.card=None
        self.depth=0
        self.rows=[]
        self.page_text=[]
        self.ignore_level=0
        self.range_text=None
        self.in_range=False
        self.ignored_unidentified=[]

    def handle_starttag(self, tag, attrs):
        attr=dict(attrs)
        if tag in ('script','style','noscript'):
            self.ignore_level+=1
        if tag=='div' and 'itemcolumn' in (attr.get('class') or '').split():
            if self.card is not None:
                raise ValueError('NESTED_WEBSITE_ITEMCOLUMN')
            self.card={'value':attr.get('data-value'),'demand':attr.get('data-demand'),
                       'stability':attr.get('data-stability'),'name':None,'image':None,
                       'range':None}
            self.depth=1
            return
        if self.card is not None:
            if tag in ('div',):self.depth+=1
            if tag=='button' and attr.get('data-image') and self.card['image'] is None:
                self.card['image']=attr.get('data-image')
                self.card['name']=attr.get('data-name')
            if tag=='b' and 'itemrange' in (attr.get('class') or '').split():
                self.in_range=True;self.range_text=[]

    def handle_data(self, text):
        if self.ignore_level<=0:
            self.page_text.append(text)
        if self.card is not None and self.in_range:
            self.range_text.append(text)

    def handle_endtag(self, tag):
        if tag in ('script','style','noscript'):
            self.ignore_level=max(0,self.ignore_level-1)
        if self.in_range and tag=='b':
            self.card['range']=''.join(self.range_text).strip()
            self.in_range=False;self.range_text=None
        if self.card is not None and tag=='div':
            self.depth-=1
            if self.depth==0:
                if self.card['image'] is not None:self.rows.append(self.card)
                else:self.ignored_unidentified.append(self.card)
                self.card=None

    def finish(self):
        if self.card is not None or self.depth!=0:
            raise ValueError('UNCLOSED_WEBSITE_ITEMCARD')
        return ' '.join(self.page_text)


def _integer(value):
    if not isinstance(value,str) or not re.fullmatch(r'\d+',value):return None
    return int(value)


def _range(value):
    if value is None:return None
    s=value.replace(',','').replace('[','').replace(']','').strip()
    if s.upper()=='N/A':return None
    m=re.fullmatch(r'(\d+)\s*-\s*(\d+)',s)
    if not m:return 'INVALID'
    return int(m[1]),int(m[2])


def attest(export:bytes,registry:bytes,pages:dict):
    """Compare three independent source pages against exact SHA-pinned export.

    pages[category] = {url, httpStatus, html:bytes}. The caller is solely
    responsible for authenticating network transport; no injected metadata proves it.
    """
    try:
        mapped=ingest(export,registry)
        if type(pages) is not dict or set(pages)!=set(CATS):
            raise ValueError('THREE_CANONICAL_PAGES_REQUIRED')
        expected={(r['category'],r['image']):r for r in mapped['records']}
        match=set()
        stamps=[];page_reports=[]
        for cat in CATS:
            snap=pages[cat]
            if (type(snap) is not dict or set(snap) != {'url','httpStatus','html'}
                or snap['url']!=CANONICAL[cat] or type(snap['httpStatus']) is not int or snap['httpStatus']!=200
                or type(snap['html']) is not bytes or not 100<=len(snap['html'])<=3_000_000):
                raise ValueError('INVALID_CANONICAL_PAGE_RECEIPT:'+cat)
            h=snap['html']
            parser=_WebsiteCards()
            parser.feed(h.decode('utf-8'))
            stamp=_parse_publisher_timestamp(parser.finish())
            stamps.append(stamp)
            seen=set();ignored=[]
            for row in parser.rows:
                key=(cat,row['image'])
                if row['image'] != 'mm2'+cat+'/'+row['image'].split('/')[-1]:
                    raise ValueError('CATEGORY_IMAGE_CONFLICT:'+cat)
                if key in seen:raise ValueError('DUPLICATE_PUBLISHED_IMAGE:'+row['image'])
                seen.add(key)
                if key not in expected:
                    if key in ALLOW_EXTRA:ignored.append(row['image']);continue
                    raise ValueError('UNKNOWN_PUBLISHED_WEAPON:'+row['image'])
                source=expected[key]
                value,demand=_integer(row['value']),_integer(row['demand'])
                if value is None or demand is None or not row['stability']:
                    raise ValueError('MISSING_PUBLISHED_METRICS:'+row['image'])
                points=_range(row['range'])
                if points=='INVALID':raise ValueError('INVALID_PUBLISHED_RANGE:'+row['image'])
                low,high=points if points is not None else (value,value)
                if (value!=source['decimalValue'] or demand!=source['demand']
                    or row['stability']!=source['stability']
                    or low!=source['rangeLow'] or high!=source['rangeHigh']):
                    raise ValueError('PUBLISHED_ITEM_MISMATCH:'+row['image'])
                if source['name'].casefold() != (row['name'] or '').casefold():
                    raise ValueError('PUBLISHED_NAME_DRIFT:'+row['image'])
                match.add(key)
            if cat=='ancients' and len(parser.ignored_unidentified)>1:
                raise ValueError('UNEXPECTED_PRICELESS_ANCENT_COUNT')
            if cat!='ancients' and parser.ignored_unidentified:
                raise ValueError('UNIDENTIFIED_WEBSITE_ITEM:'+cat)
            page_reports.append({'category':cat,'url':snap['url'],'httpStatus':200,
                                 'sourceHtmlSha256':hashlib.sha256(h).hexdigest(),
                                 'publishedItemMatches':sum(k[0]==cat for k in match),
                                 'excludedKnownItems':sorted(ignored),
                                 'unidentifiedSpecialCards':len(parser.ignored_unidentified)})
        if len(set(stamps))!=1:
            raise ValueError('PUBLISHER_TIMESTAMPS_DISAGREE')
        if match!=set(expected):
            raise ValueError('PUBLISHED_COVERAGE_INCOMPLETE')
        first=datetime.fromisoformat(mapped['captureWindowUTC']['firstObservedAt'].replace('Z','+00:00'))
        if stamps[0]>first:
            raise ValueError('PUBLISHER_VERSION_POSTDATES_OPERATOR_CAPTURE')
        return {'schema':SCHEMA,'status':'RESEARCH_PARITY_CORROBORATED',
                'reason':'COMPLETE_EXACT_PUBLISHED_FIELDS_MATCH_WITH_UNTRUSTED_TRANSPORT_ORIGIN',
                'sourcePageParity':True,
                'confirmedPublisherUtc':stamps[0].isoformat().replace('+00:00','Z'),
                'operatorExportSha256':mapped['sourceExportSha256'],
                'websiteMatchedRows':len(match),'pages':page_reports,
                **AUTHORITY_DENIED}
    except (ValueError,UnicodeError,TypeError,KeyError) as err:
        return _blocked(str(err)[:180])


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--export',required=True,type=Path)
    ap.add_argument('--stage83-lua',required=True,type=Path)
    for cat in CATS:
        ap.add_argument('--'+cat+'-html',required=True,type=Path)
    args=ap.parse_args()
    try:
        sources={cat:{'url':CANONICAL[cat],'httpStatus':200,'html':getattr(args,cat+'_html').read_bytes()}
                 for cat in CATS}
        result=attest(args.export.read_bytes(),args.stage83_lua.read_bytes(),sources)
    except OSError as exc:result=_blocked('SOURCE_FILE_IO_ERROR:'+str(exc)[:110])
    print(json.dumps(result,indent=2))
    return 0 if result['status']=='RESEARCH_PARITY_CORROBORATED' else 1

if __name__=='__main__':raise SystemExit(main())
