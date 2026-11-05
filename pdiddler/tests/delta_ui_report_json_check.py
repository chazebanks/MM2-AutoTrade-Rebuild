"""Independently parse the exact ASCII payloads produced by the Lua tests."""
from pathlib import Path
import json

paths = [
    Path('/tmp/pdiddler-delta-ui-format-v2.jsonl'),
    Path('/tmp/pdiddler-delta-ui-bootstrap-v2.jsonl'),
]
counts = []


def reject_constant(value):
    raise ValueError('nonstandard JSON constant: ' + value)


for path in paths:
    assert path.is_file(), 'actual Lua payload fixture missing: ' + str(path)
    rows = path.read_bytes().splitlines()
    assert rows, 'actual Lua payload fixture was empty: ' + str(path)
    for index, row in enumerate(rows, 1):
        assert len(row) <= 16384, f'formatter output exceeded its 16KiB byte budget in {path}:{index}'
        assert row and all(32 <= byte <= 126 for byte in row), f'non-ASCII/control byte in {path}:{index}'
        parsed = json.loads(row.decode('ascii'), parse_constant=reject_constant)
        assert isinstance(parsed, dict), f'complete report object required in {path}:{index}'
    counts.append(len(rows))
print(f'PASS independent Python JSON parser: {counts[0]} formatter and {counts[1]} actual bootstrap payloads are complete printable ASCII JSON objects')
