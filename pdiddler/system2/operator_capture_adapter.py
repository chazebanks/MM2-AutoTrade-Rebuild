"""Deterministic OFFLINE crosswalk for the Nov 13 operator Supreme calculator export.

An uploaded browser JSON cannot authenticate its own publisher version or prove an
MM2 server-side item key. This module never authorizes an offer, Accept, strategy
learning, profit webhook, or live market quote. No website/network calls.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys

from pdiddler.system2.catalog_discovery_diff import (  # pinned Stage83 loader
    SOURCE_BLOB_SHA, SOURCE_COMMIT, load_historical_registry,
)

SCHEMA = 'gingerscope-operator-189-offline-key-crosswalk-v1'
EXPORT_SCHEMA = 'gingerscope-supreme-189-offline-export-v1'
EXPORT_SHA256 = 'bb91b545637a0fe8d7dcceebef9070ee9a76210015bdc1737fd78f068acaeb4f'
CATALOG_FINGERPRINT = '44d1000e'
SOURCE_TEXT = 'Supreme MM2 calculator, operator browser capture'
EXPECTED_COUNTS = {'ancients': 15, 'godlies': 128, 'chromas': 46}
EXPORT_KEYS = {'schema', 'captureScope', 'catalogCapturedAt', 'firstValueCollectedAt',
               'exportedAt', 'historicalCatalogFingerprint', 'expected', 'actual',
               'publisherVersion', 'source', 'records', 'authorizesTrade',
               'authorizesOffer', 'authorizesAccept', 'serverCompletionProven'}
ROW_KEYS = {'category', 'image', 'name', 'valueDisplay', 'decimalValue',
            'previousDecimalValue', 'rangeLow', 'rangeHigh', 'demand',
            'stability', 'observedAt'}
AUTHORITY_DENIED = {
    'readOnly': True,
    'offlineResearchOnly': True,
    'publishedCurrentPriceAuthenticated': False,
    'marketSourceUsableForLiveOffer': False,
    'verifiedMarketQuote': False,
    'verifiedGameItemIdentity': False,
    'independentLiveGameKeyIdentityVerified': False,
    'observedCompletedTradeLiquidityVerified': False,
    'mayFeedStage120AsVerifiedMarket': False,
    'authorizesOffer': False,
    'authorizesTrade': False,
    'authorizesAccept': False,
    'mayRecordCompletedTrade': False,
    'mayReportProfit': False,
    'maySendDiscordWebhook': False,
    'mayUseForStrategyLearning': False,
    'serverCompletionProven': False,
    'tradeOutcome': 'UNKNOWN',
}


def _reject_duplicates(pairs):
    data = {}
    for key, value in pairs:
        if key in data:
            raise ValueError('JSON_DUPLICATE_KEY:' + key[:60])
        data[key] = value
    return data


def _bad_constant(value):
    raise ValueError('NONFINITE_JSON_NUMBER:' + value)


def _date(value):
    if not isinstance(value, str) or not re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{3})?Z', value):
        raise ValueError('INVALID_UTC_TIMESTAMP')
    try:
        return datetime.fromisoformat(value[:-1] + '+00:00').astimezone(timezone.utc)
    except ValueError as exc:
        raise ValueError('INVALID_UTC_TIMESTAMP') from exc


def _number(value):
    return type(value) in (int, float) and 0 <= value <= 1_000_000_000 and float(value).is_integer()


def _display_matches(display, decimal):
    return type(display) is str and bool(re.fullmatch(r'\*?(?:0|[1-9]\d*)', display)) and int(display.lstrip('*')) == decimal


def ingest(export_bytes: bytes, registry_bytes: bytes, *, expected_export_sha256: str = EXPORT_SHA256):
    """Ingest only complete pinned operator capture; never emit partial mappings.

    expected_export_sha256 is injectable for isolated synthetic regression tests;
    the CLI always uses the constant immutable operator file SHA256 above.
    """
    if type(export_bytes) is not bytes or len(export_bytes) > 512_000 or not export_bytes:
        raise ValueError('INVALID_EXPORT_BYTES')
    digest = hashlib.sha256(export_bytes).hexdigest()
    if not re.fullmatch(r'[0-9a-f]{64}', expected_export_sha256) or digest != expected_export_sha256:
        raise ValueError('OPERATOR_EXPORT_SHA256_MISMATCH')
    registry = load_historical_registry(registry_bytes)
    if len(registry) != 189:
        raise ValueError('HISTORICAL_REGISTRY_INCOMPLETE')
    try:
        obj = json.loads(export_bytes.decode('utf-8'), object_pairs_hook=_reject_duplicates,
                         parse_constant=_bad_constant)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError('INVALID_EXPORT_JSON') from exc
    if type(obj) is not dict or set(obj) != EXPORT_KEYS:
        raise ValueError('INVALID_EXPORT_FIELDS')
    if (obj['schema'] != EXPORT_SCHEMA or obj['captureScope'] != 'OFFLINE_REVIEW_ONLY'
            or obj['historicalCatalogFingerprint'] != CATALOG_FINGERPRINT
            or obj['publisherVersion'] is not None or obj['source'] != SOURCE_TEXT
            or type(obj['expected']) is not int or obj['expected'] != 189
            or type(obj['actual']) is not int or obj['actual'] != 189
            or any(obj[k] is not False for k in (
                'authorizesTrade', 'authorizesOffer', 'authorizesAccept', 'serverCompletionProven'))
            or type(obj['records']) is not list or len(obj['records']) != 189):
        raise ValueError('EXPORT_CONTRACT_REJECTED')
    catalog_at, started, exported = (_date(obj[k]) for k in
                                      ('catalogCapturedAt', 'firstValueCollectedAt', 'exportedAt'))
    if not (catalog_at <= started <= exported):
        raise ValueError('CAPTURE_WINDOW_INVALID')
    result_rows = []
    seen = set()
    count = {cat: 0 for cat in EXPECTED_COUNTS}
    drift = []
    null_previous = starred = ranged = 0
    dates = []
    for r in obj['records']:
        if type(r) is not dict or set(r) != ROW_KEYS:
            raise ValueError('INVALID_RECORD_FIELDS')
        if type(r['category']) is not str or type(r['image']) is not str:
            raise ValueError('INVALID_WEAPON_IDENTITY')
        ident = (r['category'], r['image'])
        if ident not in registry or ident in seen:
            raise ValueError('UNKNOWN_OR_DUPLICATE_WEAPON_IDENTITY:' + str(ident)[:150])
        seen.add(ident)
        historical = registry[ident]
        expected_name = historical['expectedName']
        actual_name = r['name']
        if type(actual_name) is not str:
            raise ValueError('INVALID_WEAPON_LABEL')
        if actual_name != expected_name:
            if not (historical['rawGameKeyCandidate'] in ('BattleAxe', 'BattleAxe2')
                    and actual_name.casefold() == expected_name.casefold()):
                raise ValueError('UNAUTHORIZED_WEAPON_LABEL_DRIFT')
            drift.append({'rawGameKeyCandidate':historical['rawGameKeyCandidate'],
                          'expected':expected_name, 'observed':actual_name})
        if (not _number(r['decimalValue']) or r['decimalValue'] <= 0
                or not _number(r['rangeLow']) or not _number(r['rangeHigh'])
                or not (r['rangeLow'] <= r['decimalValue'] <= r['rangeHigh'])
                or (r['previousDecimalValue'] is not None and not _number(r['previousDecimalValue']))
                or not _display_matches(r['valueDisplay'], r['decimalValue'])
                or type(r['demand']) is not int or not 0 <= r['demand'] <= 10
                or type(r['stability']) is not str or not 1 <= len(r['stability']) <= 60):
            raise ValueError('INVALID_SOURCE_VALUE_FIELDS:' + r['image'])
        observed = _date(r['observedAt'])
        if not started <= observed <= exported:
            raise ValueError('OBSERVATION_OUTSIDE_CAPTURE_WINDOW')
        dates.append(observed)
        count[r['category']] += 1
        if r['previousDecimalValue'] is None:
            null_previous += 1
        if r['valueDisplay'].startswith('*'):
            starred += 1
        if r['rangeLow'] != r['rangeHigh']:
            ranged += 1
        result_rows.append({
            'rawGameKeyCandidate': historical['rawGameKeyCandidate'],
            'gameItemTypeCandidate': historical['weaponTypeCandidate'],
            'gameRarityCandidate': historical['rarityCandidate'],
            'chromaCandidate':r['category'] == 'chromas',
            **r,
        })
    if len(seen) != len(registry) or set(seen) != set(registry) or count != EXPECTED_COUNTS:
        raise ValueError('INCOMPLETE_WEAPON_COVERAGE')
    if len(drift) != 2:
        raise ValueError('UNEXPECTED_LABEL_DRIFT_SET')
    result_rows.sort(key=lambda r: r['rawGameKeyCandidate'])
    return {
        'schema': SCHEMA,
        'status': 'OFFLINE_CROSSWALK_READY',
        'sourceExportSha256': digest,
        'originalRegistryGitBlob': SOURCE_BLOB_SHA,
        'originalRegistryCommit': SOURCE_COMMIT,
        'publisherVersion': None,
        'source': SOURCE_TEXT,
        'captureWindowUTC': {
            'catalogCapturedAt': obj['catalogCapturedAt'],
            'firstValueCollectedAt': obj['firstValueCollectedAt'],
            'firstObservedAt': min(dates).isoformat(timespec='milliseconds').replace('+00:00','Z'),
            'lastObservedAt': max(dates).isoformat(timespec='milliseconds').replace('+00:00','Z'),
            'exportedAt': obj['exportedAt'],
        },
        'statistics': {'total':len(result_rows), 'byCategory':count,
                       'nullPreviousValue':null_previous, 'starredDisplay':starred,
                       'rangeValued':ranged, 'approvedCaseOnlyLabelDrift':drift},
        'records':result_rows,
        **AUTHORITY_DENIED,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export', type=Path, required=True)
    parser.add_argument('--stage83-lua', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True,
                        help='Explicit LOCAL research-only output path; never write into a public repo')
    args = parser.parse_args(argv)
    try:
        result = ingest(args.export.read_bytes(), args.stage83_lua.read_bytes())
    except (ValueError, OSError) as exc:
        print(json.dumps({'schema':SCHEMA,'status':'BLOCKED','reason':str(exc),**AUTHORITY_DENIED},
                         sort_keys=True))
        return 1
    # Expose all 189 source values only in an explicitly named local output file.
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key:val for key,val in result.items() if key!='records'},
                     ensure_ascii=False, sort_keys=True))
    return 0

if __name__ == '__main__':
    sys.exit(main())
