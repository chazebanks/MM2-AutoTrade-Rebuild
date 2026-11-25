"""Versioned local state for offline Gingerscope advisory sessions.

Manual observations never settle trades. Separately scoped synthetic databases
can exercise exact bilateral reconciliation without creating actual results.
SQLite serializes mutations and rolls back interrupted writes.
"""
from __future__ import annotations

from collections import Counter
from contextlib import contextmanager
from datetime import datetime, timezone
from hashlib import sha256
from hmac import compare_digest
import json
import os
from pathlib import Path
import re
import secrets
import sqlite3
import stat

from pdiddler.system2.manual_portfolio_review import (
    COPIES_PER_SLOT_ASSUMPTION, ITEM_ID, MAX_ACCOUNT_COPIES_PER_ITEM, PHYSICAL_SLOTS,
)

SCHEMA_VERSION = 2
MAX_REPORT_BYTES = 8_388_608
_DIGEST = re.compile(r"[a-f0-9]{64}\Z")
_ID = re.compile(r"[A-Za-z0-9_-]{1,128}\Z")
_OFFER_KINDS = {"OFFER_OBSERVED", "MAIN_OFFER_REVISION", "PARTNER_OFFER_REVISION"}
_PENDING_OUTCOMES = {"PARTNER_DECLINED", "PARTNER_NO_RESPONSE_TIMEOUT"}
_TRADE_OUTCOMES = {"MAIN_CANCELLED", "PARTNER_CANCELLED", "CLIENT_WINDOW_CLOSED_UNKNOWN"}
_INDICATORS = {"MAIN_ACCEPT_INDICATOR", "PARTNER_ACCEPT_INDICATOR", "CLIENT_INVENTORY_DELTA_OBSERVED"}
_UNRESOLVED = {"SESSION_INTERRUPTED", "CLIENT_WINDOW_CLOSED_UNKNOWN", "LEASE_EXPIRED"}
_SETTLED = "CORROBORATED_SYNTHETIC_SETTLEMENT"
_EVENT_FIELDS = {"event_id", "session_id", "sequence", "revision", "kind"}
_WITNESS_FIELDS = {"side", "source_id", "before", "after"}

_SCHEMA_V1 = (
    "CREATE TABLE metadata (scope TEXT NOT NULL CHECK (scope IN ('manual', 'synthetic')))",
    """CREATE TABLE markets (
        sha256 TEXT PRIMARY KEY, published TEXT NOT NULL, captured TEXT NOT NULL,
        expires TEXT NOT NULL, prices TEXT NOT NULL CHECK (json_valid(prices))
    )""",
    """CREATE TABLE inputs (
        revision INTEGER PRIMARY KEY, market TEXT NOT NULL REFERENCES markets(sha256),
        accounts TEXT NOT NULL CHECK (json_valid(accounts))
    )""",
    """CREATE TABLE sessions (
        id TEXT PRIMARY KEY, account TEXT NOT NULL CHECK (account IN ('main', 'alt')),
        token_digest TEXT NOT NULL, input_revision INTEGER NOT NULL REFERENCES inputs(revision),
        counterparty TEXT CHECK (counterparty IS NULL OR json_valid(counterparty)),
        phase TEXT NOT NULL CHECK (phase IN ('PENDING', 'IN_TRADE', 'CLOSED')), outcome TEXT,
        sequence INTEGER NOT NULL CHECK (sequence>=0), revision INTEGER NOT NULL CHECK (revision>=0),
        last_seen TEXT NOT NULL, lease_until TEXT NOT NULL
    )""",
    "CREATE UNIQUE INDEX one_active_session ON sessions ((1)) WHERE outcome IS NULL",
    """CREATE TABLE events (
        id TEXT PRIMARY KEY, session TEXT NOT NULL REFERENCES sessions(id),
        sequence INTEGER NOT NULL, revision INTEGER NOT NULL, kind TEXT NOT NULL,
        observed TEXT NOT NULL, payload TEXT NOT NULL CHECK (json_valid(payload)),
        UNIQUE (session, sequence)
    )""",
    """CREATE TABLE evaluations (
        id TEXT PRIMARY KEY, input_revision INTEGER NOT NULL REFERENCES inputs(revision),
        session TEXT REFERENCES sessions(id), offer_revision INTEGER, session_sequence INTEGER,
        evaluated TEXT NOT NULL, report TEXT NOT NULL CHECK (json_valid(report))
    )""",
    """CREATE TABLE settlements (
        id TEXT PRIMARY KEY, session TEXT NOT NULL UNIQUE REFERENCES sessions(id),
        resulting_revision INTEGER NOT NULL REFERENCES inputs(revision),
        receipt TEXT NOT NULL CHECK (json_valid(receipt)),
        evidence TEXT NOT NULL CHECK (json_valid(evidence)),
        listed_delta INTEGER NOT NULL CHECK (listed_delta>=0)
    )""",
)
_SCHEMA = _SCHEMA_V1 + (
    """CREATE TABLE review_configuration (
        revision INTEGER PRIMARY KEY, settings TEXT NOT NULL CHECK (json_valid(settings))
    )""",
    "CREATE INDEX evaluations_by_input_session ON evaluations (input_revision, session)",
)


class StateError(ValueError):
    """State, input, or evidence failure with a message suitable for local status."""


def _clock(text):
    try:
        if type(text) is not str or len(text) > 40 or "T" not in text:
            raise ValueError
        value = datetime.fromisoformat(text.replace("Z", "+00:00"))
        if value.tzinfo is None:
            raise ValueError
        return value.astimezone(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    except (ValueError, OverflowError):
        raise StateError("Use a timestamp with a UTC offset.") from None


def _key(value):
    if type(value) is not str or not _ID.fullmatch(value):
        raise StateError("Use a bounded opaque identifier.")
    return value


def _natural(value, *, minimum=0):
    if type(value) is not int or not minimum <= value <= 2_147_483_647:
        raise StateError("Use a bounded integer revision or sequence.")
    return value


def _json(value):
    try:
        return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    except (ValueError, TypeError, RecursionError):
        raise StateError("State payload must have a finite JSON representation.") from None


def encode_evaluation_report(report):
    """Validate the size and representation used by persistent evaluations."""
    if type(report) is not dict:
        raise StateError("Evaluation requires a JSON report object.")
    encoded = _json(report)
    if len(encoded) > MAX_REPORT_BYTES:
        raise StateError("The evaluation exceeds the local report size limit.")
    return encoded


def _digest(value):
    return sha256(value.encode("utf-8")).hexdigest()


def _holdings(value, *, limit=400, max_quantity=MAX_ACCOUNT_COPIES_PER_ITEM):
    if type(value) is not dict or len(value) > limit:
        raise StateError("Holdings must be a bounded map of canonical item IDs to quantities.")
    for item, quantity in value.items():
        if (type(item) is not str or not ITEM_ID.fullmatch(item)
                or type(quantity) is not int or not 1 <= quantity <= max_quantity):
            raise StateError("Holdings require canonical item IDs and positive integer quantities.")
    return value


def _accounts(value):
    if type(value) is not dict or set(value) != {"main", "alt"}:
        raise StateError("Supply separate main and alt holdings.")
    return {account: _holdings(holdings) for account, holdings in value.items()}


def _after(before, outgoing, incoming):
    if any(before.get(item, 0) < quantity for item, quantity in outgoing.items()):
        raise StateError("The observed outgoing quantities exceed the starting holdings.")
    return _holdings(dict(Counter(before) - Counter(outgoing) + Counter(incoming)))


def _open_private_file(path):
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or (os.name == "posix" and info.st_mode & 0o077):
            raise StateError("State must be a private regular file.")
    else:
        os.close(descriptor)


class StateStore:
    """Open a private SQLite file. Leases are fenced by an unpersisted token."""

    def __init__(self, path, *, scope="manual"):
        if scope not in ("manual", "synthetic"):
            raise StateError("Choose manual or synthetic state scope.")
        self._scope = scope
        path = Path(path)
        self._db = None
        try:
            _open_private_file(path)
            self._db = sqlite3.connect(path, isolation_level=None)
            self._db.row_factory = sqlite3.Row
            self._db.execute("PRAGMA foreign_keys=ON")
            with self._write():
                version = self._db.execute("PRAGMA user_version").fetchone()[0]
                if version == 0:
                    if self._db.execute("SELECT name FROM sqlite_master LIMIT 1").fetchone():
                        raise StateError("An unrecognized state schema has no supported migration.")
                    for statement in _SCHEMA:
                        self._db.execute(statement)
                    self._db.execute("INSERT INTO metadata VALUES (?)", (scope,))
                    self._db.execute(f"PRAGMA user_version={SCHEMA_VERSION}")
                elif version == 1:
                    self._verify(_SCHEMA_V1)
                    for statement in _SCHEMA[len(_SCHEMA_V1):]:
                        self._db.execute(statement)
                    self._db.execute("PRAGMA user_version=2")
                elif version != SCHEMA_VERSION:
                    raise StateError("The state schema version has no supported migration.")
                self._verify()
        except (OSError, sqlite3.DatabaseError, StateError) as error:
            self.close()
            if isinstance(error, StateError):
                raise
            raise StateError("The state file cannot be opened or is corrupt.") from None

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    @property
    def scope(self):
        return self._scope

    def close(self):
        if self._db is not None:
            self._db.close()
            self._db = None

    @contextmanager
    def _write(self):
        try:
            self._db.execute("BEGIN IMMEDIATE")
            try:
                yield
                self._db.execute("COMMIT")
            except BaseException:
                if self._db.in_transaction:
                    self._db.execute("ROLLBACK")
                raise
        except sqlite3.DatabaseError:
            raise StateError("The state transaction failed.") from None

    def _verify(self, schema=_SCHEMA):
        definitions = {row[0] for row in self._db.execute(
            "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL"
        )}
        if definitions != set(schema):
            raise StateError("State schema definitions differ from the supported version.")
        if self._db.execute("PRAGMA quick_check(1)").fetchone()[0] != "ok":
            raise StateError("State integrity verification failed.")
        if self._db.execute("PRAGMA foreign_key_check").fetchone():
            raise StateError("A stored dependency is missing.")
        rows = self._db.execute("SELECT scope FROM metadata").fetchall()
        if len(rows) != 1 or rows[0][0] != self.scope:
            raise StateError("The existing state belongs to another scope.")
        if self.scope == "manual" and self._db.execute("SELECT 1 FROM settlements LIMIT 1").fetchone():
            raise StateError("Manual state contains unexpected synthetic rows.")

    def _input_row(self, revision=None):
        query = """SELECT inputs.*, markets.published, markets.captured, markets.expires, markets.prices
                   FROM inputs JOIN markets ON market=sha256"""
        if revision is None:
            return self._db.execute(query + " ORDER BY revision DESC LIMIT 1").fetchone()
        return self._db.execute(query + " WHERE revision=?", (_natural(revision, minimum=1),)).fetchone()

    def _put_inputs(self, market, accounts):
        previous = self._input_row()
        if previous and (previous["market"], previous["accounts"]) == (market, accounts):
            return previous["revision"]
        return self._db.execute(
            "INSERT INTO inputs (market, accounts) VALUES (?, ?)", (market, accounts)
        ).lastrowid

    def _require_settlement_clock(self, revision, clock):
        if self._db.execute(
            """SELECT 1 FROM settlements t JOIN sessions settled ON settled.id=t.session
               WHERE t.resulting_revision<=? AND settled.last_seen>? LIMIT 1""",
            (revision, clock),
        ).fetchone():
            raise StateError("The clock predates a committed synthetic settlement in this input revision.")

    def sync_inputs(self, *, market_sha256, publisher_updated_at, captured_at, expires_at,
                    accounts, listed_values=None, expected_input_revision=None,
                    expected_configuration_revision=None, evaluated_at=None):
        """Persist validated Supreme provenance and manually supplied account holdings.

        The caller verifies the corresponding archive bytes before calling. Listed
        values are used only for separately scoped synthetic accounting.
        """
        prepared = self._prepare_inputs(
            market_sha256, publisher_updated_at, captured_at, expires_at,
            accounts, listed_values, expected_input_revision,
        )
        evaluated = None if evaluated_at is None else _clock(evaluated_at)
        with self._write():
            if (expected_configuration_revision is not None
                    and self.review_configuration()[0] != expected_configuration_revision):
                raise StateError("Review configuration changed. Evaluate the inputs again.")
            revision = self._sync_prepared(*prepared)
            if evaluated is not None:
                row = self._input_row(revision)
                if not row["captured"] <= evaluated <= row["expires"]:
                    raise StateError("The review's market source is unavailable at the evaluation time.")
                self._require_settlement_clock(revision, evaluated)
            return revision

    def review_configuration(self):
        """Read the latest explicit local search defaults and their revision."""
        row = self._db.execute(
            "SELECT revision, settings FROM review_configuration ORDER BY revision DESC LIMIT 1"
        ).fetchone()
        if row is None:
            return 0, {}
        settings = json.loads(row["settings"])
        if type(settings) is not dict:
            raise StateError("The stored review configuration is invalid.")
        return row["revision"], settings

    def set_review_configuration(self, settings):
        """Save explicit configuration and retire advice prepared with earlier defaults."""
        encoded = _json(settings)
        if type(settings) is not dict or len(encoded) > 4096:
            raise StateError("The review configuration must be a bounded JSON object.")
        with self._write():
            revision, existing = self.review_configuration()
            if _json(existing) == encoded:
                return revision
            if self._db.execute("SELECT 1 FROM sessions WHERE outcome IS NULL").fetchone():
                raise StateError("Stop or recover the active session before changing configuration.")
            current = self._input_row()
            if current is not None:
                self._db.execute("INSERT INTO inputs (market, accounts) VALUES (?, ?)",
                                 (current["market"], current["accounts"]))
            return self._db.execute(
                "INSERT INTO review_configuration (settings) VALUES (?)", (encoded,)
            ).lastrowid

    def _prepare_inputs(self, market_sha256, publisher_updated_at, captured_at, expires_at,
                        accounts, listed_values=None, expected_input_revision=None):
        if type(market_sha256) is not str or not _DIGEST.fullmatch(market_sha256):
            raise StateError("Provide the verified edition SHA-256.")
        published, captured, expires = map(_clock, (publisher_updated_at, captured_at, expires_at))
        if not published <= captured < expires:
            raise StateError("Market publication, capture and expiry are inconsistent.")
        stocks = _json(_accounts(accounts))
        if listed_values is not None and self.scope != "synthetic":
            raise StateError("Manual state stores edition references without synthetic valuations.")
        prices = _json(_holdings({} if listed_values is None else listed_values,
                                 max_quantity=2_147_483_647))
        metadata = (published, captured, expires, prices)
        if expected_input_revision is not None:
            _natural(expected_input_revision)
        return market_sha256, metadata, stocks, expected_input_revision

    def _sync_prepared(self, market_sha256, metadata, stocks, expected_revision):
        current = self._input_row()
        current_revision = 0 if current is None else current["revision"]
        if expected_revision is not None and current_revision != expected_revision:
            raise StateError("A newer portfolio revision has been recorded.")
        if (current is not None and current["market"] != market_sha256
                and metadata[0] <= current["published"]):
            raise StateError("A replacement market edition requires a newer publisher version.")
        existing = self._db.execute(
            "SELECT published, captured, expires, prices FROM markets WHERE sha256=?",
            (market_sha256,),
        ).fetchone()
        if existing is None:
            self._db.execute("INSERT INTO markets VALUES (?, ?, ?, ?, ?)", (market_sha256, *metadata))
        elif tuple(existing) != metadata:
            raise StateError("The same edition hash has conflicting metadata.")
        if current is not None and (current["market"], current["accounts"]) == (market_sha256, stocks):
            return current_revision
        if expected_revision is None and self._db.execute(
            "SELECT 1 FROM sessions WHERE outcome IS NULL"
        ).fetchone():
            raise StateError("Changing active inputs requires the current portfolio revision.")
        return self._put_inputs(market_sha256, stocks)

    def inputs(self, revision=None):
        """Read local holdings and immutable source references for one revision."""
        row = self._input_row(revision)
        if row is None:
            return None
        return {
            "inputRevision": row["revision"], "marketSha256": row["market"],
            "publisherUpdatedAt": row["published"], "capturedAt": row["captured"],
            "expiresAt": row["expires"], "accounts": _accounts(json.loads(row["accounts"])),
        }

    def _session(self, session_id):
        row = self._db.execute("SELECT * FROM sessions WHERE id=?", (_key(session_id),)).fetchone()
        if row is None:
            raise StateError("No matching offline session exists.")
        return row

    def _owned(self, session_id, owner):
        row = self._session(session_id)
        if not compare_digest(row["token_digest"], _digest(_key(owner))):
            raise StateError("The session is owned by another caller or lease.")
        return row

    @staticmethod
    def _require_active(row, now):
        if row["outcome"] is not None or not row["last_seen"] <= now < row["lease_until"]:
            raise StateError("The session has closed, expired, or moved past this observation.")

    def _expire(self, now):
        return self._db.execute(
            """UPDATE sessions SET phase='CLOSED', outcome='LEASE_EXPIRED'
               WHERE outcome IS NULL AND lease_until<=?""",
            (now,),
        ).rowcount

    def recover(self, *, now):
        """Retire expired owners and retain unresolved history."""
        now = _clock(now)
        with self._write():
            return self._expire(now)

    def start_session(self, session_id, *, account, now, lease_until, counterparty=None, inputs=None):
        """Acquire ownership and optionally record matching starting inputs atomically."""
        session_id, now, lease_until = _key(session_id), _clock(now), _clock(lease_until)
        if account not in ("main", "alt") or now >= lease_until:
            raise StateError("Use a defined account and a lease that expires after opening.")
        if counterparty is not None and self.scope != "synthetic":
            raise StateError("Initial counterparty stock belongs in synthetic state.")
        partner = None if counterparty is None else _json(_holdings(counterparty))
        if inputs is not None and type(inputs) is not dict:
            raise StateError("Session inputs must be an exact input object.")
        try:
            prepared = None if inputs is None else self._prepare_inputs(**inputs)
        except TypeError:
            raise StateError("Session inputs have missing or unexpected fields.") from None
        token = secrets.token_hex(32)
        with self._write():
            self._expire(now)
            if self._db.execute("SELECT 1 FROM sessions WHERE outcome IS NULL").fetchone():
                raise StateError("Another offline session already owns the observation interface.")
            if self._db.execute("SELECT 1 FROM sessions WHERE id=?", (session_id,)).fetchone():
                raise StateError("A closed offline session cannot be reopened or reused.")
            if prepared is not None:
                self._sync_prepared(*prepared)
            initial = self._input_row()
            if initial is None:
                raise StateError("Record portfolio and market inputs before opening a session.")
            if not initial["captured"] <= now <= initial["expires"]:
                raise StateError("The session's market source is unavailable at the opening time.")
            self._require_settlement_clock(initial["revision"], now)
            self._db.execute(
                "INSERT INTO sessions VALUES (?, ?, ?, ?, ?, 'PENDING', NULL, 0, 0, ?, ?)",
                (session_id, account, _digest(token), initial["revision"], partner, now, lease_until),
            )
        return token

    def _apply_event(self, row, event, payload, now, phase, outcome):
        self._db.execute(
            "INSERT INTO events VALUES (?, ?, ?, ?, ?, ?, ?)",
            (event["event_id"], row["id"], event["sequence"], event["revision"],
             event["kind"], now, payload),
        )
        self._db.execute(
            """UPDATE sessions SET sequence=?, revision=?, last_seen=?, phase=?, outcome=?
               WHERE id=?""",
            (event["sequence"], event["revision"], now, phase, outcome, row["id"]),
        )

    def observe(self, event, *, owner, now):
        """Record a caller-supplied client observation. Exact redelivery is a no-op."""
        now = _clock(now)
        if type(event) is not dict or type(event.get("kind")) is not str:
            raise StateError("Use an exact offline observation envelope.")
        kind = event["kind"]
        offer = kind in _OFFER_KINDS
        if set(event) != (_EVENT_FIELDS | {"give", "receive"} if offer else _EVENT_FIELDS):
            raise StateError("Unexpected or missing observation fields.")
        event_id = _key(event["event_id"])
        sequence = _natural(event["sequence"], minimum=1)
        revision = _natural(event["revision"])
        if offer:
            _holdings(event["give"], limit=PHYSICAL_SLOTS)
            _holdings(event["receive"], limit=PHYSICAL_SLOTS)
        payload = _json(event)
        with self._write():
            row = self._owned(event["session_id"], owner)
            previous = self._db.execute("SELECT payload FROM events WHERE id=?", (event_id,)).fetchone()
            if previous:
                if previous["payload"] != payload:
                    raise StateError("An event identifier has conflicting evidence.")
                return False
            self._require_active(row, now)
            if sequence != row["sequence"] + 1 or revision != row["revision"] + int(offer):
                raise StateError("Observation sequence or offer revision is stale or incomplete.")
            phase, outcome = row["phase"], None
            if kind == "SESSION_INTERRUPTED":
                outcome = kind
            elif phase == "PENDING" and kind in _PENDING_OUTCOMES:
                outcome = kind
            elif phase == "PENDING" and kind == "PARTNER_REQUEST_ACCEPTED":
                phase = "IN_TRADE"
            elif phase == "IN_TRADE" and kind in _TRADE_OUTCOMES:
                outcome = kind
            elif phase == "IN_TRADE" and kind in _INDICATORS:
                pass
            elif phase == "IN_TRADE" and (
                (kind == "OFFER_OBSERVED" and revision == 1)
                or (offer and kind != "OFFER_OBSERVED" and revision > 1)
            ):
                pass
            else:
                raise StateError("The observation kind is unsupported at this session stage.")
            self._apply_event(row, event, payload, now, "CLOSED" if outcome else phase, outcome)
            return True

    def stop_session(self, session_id, *, owner, now):
        """End an owned lease and keep the unresolved observation record."""
        now = _clock(now)
        with self._write():
            row = self._owned(session_id, owner)
            if row["outcome"] is not None:
                return False
            self._require_active(row, now)
            event = {"event_id": secrets.token_hex(16), "session_id": session_id,
                     "sequence": row["sequence"] + 1, "revision": row["revision"],
                     "kind": "SESSION_INTERRUPTED"}
            self._apply_event(row, event, _json(event), now, "CLOSED", event["kind"])
            return True

    def record_evaluation(self, evaluation_id, *, input_revision, report, evaluated_at,
                          session_id=None, offer_revision=None):
        """Save a snapshot only while the supplied source and offer are current."""
        evaluation_id = _key(evaluation_id)
        input_revision = _natural(input_revision, minimum=1)
        evaluated = _clock(evaluated_at)
        if (session_id is None) != (offer_revision is None):
            raise StateError("Evaluation requires an optional exact session revision.")
        if offer_revision is not None:
            _natural(offer_revision, minimum=1)
        report = encode_evaluation_report(report)
        with self._write():
            previous = self._db.execute(
                """SELECT input_revision, session, offer_revision, evaluated, report
                   FROM evaluations WHERE id=?""", (evaluation_id,),
            ).fetchone()
            if previous:
                if tuple(previous) != (input_revision, session_id, offer_revision, evaluated, report):
                    raise StateError("An evaluation identifier has conflicting evidence.")
                return False
            current = self._input_row()
            if (current is None or current["revision"] != input_revision
                    or not current["captured"] <= evaluated <= current["expires"]):
                raise StateError("The evaluation's portfolio or source edition is stale.")
            self._require_settlement_clock(input_revision, evaluated)
            sequence = None
            if session_id is not None:
                session = self._session(session_id)
                self._require_active(session, evaluated)
                if session["input_revision"] != input_revision:
                    raise StateError("The evaluation does not match the session's starting inputs.")
                if session["revision"] != offer_revision:
                    raise StateError("The evaluation's offer revision is stale.")
                sequence = session["sequence"]
            self._db.execute(
                "INSERT INTO evaluations VALUES (?, ?, ?, ?, ?, ?, ?)",
                (evaluation_id, input_revision, session_id, offer_revision, sequence, evaluated, report),
            )
            return True

    def _evaluation_row(self, evaluation_id):
        return self._db.execute("SELECT * FROM evaluations WHERE id=?", (_key(evaluation_id),)).fetchone()

    @staticmethod
    def _report(row):
        return {
            "evaluationId": row["id"], "inputRevision": row["input_revision"],
            "sessionId": row["session"], "offerRevision": row["offer_revision"],
            "evaluatedAt": row["evaluated"], "report": json.loads(row["report"]),
        }

    def evaluation_history(self, evaluation_id):
        """Return a stored research result with no currentness guarantee."""
        row = self._evaluation_row(evaluation_id)
        return None if row is None else self._report(row)

    def current_evaluation(self, evaluation_id, *, now):
        """Return an evaluation only while its source, inventory and evidence are current."""
        now = _clock(now)
        # One read statement ensures all revision and lease conditions refer to
        # the same committed state, even while another process writes.
        row = self._db.execute(
            """SELECT e.* FROM evaluations e
               JOIN inputs i ON i.revision=e.input_revision
               JOIN markets m ON m.sha256=i.market
               LEFT JOIN sessions s ON s.id=e.session
               WHERE e.id=? AND i.revision=(SELECT max(revision) FROM inputs)
                 AND e.evaluated<=? AND m.expires>=?
                 AND NOT EXISTS (
                     SELECT 1 FROM settlements t JOIN sessions settled ON settled.id=t.session
                     WHERE t.resulting_revision<=i.revision AND settled.last_seen>e.evaluated
                 )
                 AND ((e.session IS NULL AND NOT EXISTS (
                           SELECT 1 FROM evaluations newer WHERE newer.input_revision=e.input_revision
                               AND newer.session IS NULL
                               AND (newer.evaluated>e.evaluated
                                    OR (newer.evaluated=e.evaluated AND newer.rowid>e.rowid))
                      )) OR (e.session IS NOT NULL AND s.outcome IS NULL AND s.lease_until>?
                             AND s.sequence=e.session_sequence AND s.revision=e.offer_revision))""",
            (_key(evaluation_id), now, now, now),
        ).fetchone()
        return None if row is None else self._report(row)

    def settle_synthetic(self, session_id, *, owner, now, transaction_id, revision, witnesses):
        """Exercise settlement with two exact, disagreeing-or-matching synthetic sources."""
        if self.scope != "synthetic":
            raise StateError("Only isolated synthetic state accepts simulated settlements.")
        now, transaction_id = _clock(now), _key(transaction_id)
        revision = _natural(revision, minimum=1)
        if type(witnesses) is not list or len(witnesses) != 2:
            raise StateError("Provide both synthetic inventory witnesses.")
        sides = {}
        for witness in witnesses:
            if type(witness) is not dict or set(witness) != _WITNESS_FIELDS:
                raise StateError("A synthetic inventory witness has unexpected fields.")
            side = witness["side"]
            if side not in ("account", "counterparty") or side in sides:
                raise StateError("Provide one inventory witness per side.")
            sides[side] = {"source_id": _key(witness["source_id"]),
                           "before": _holdings(witness["before"]), "after": _holdings(witness["after"])}
        if sides["account"]["source_id"] == sides["counterparty"]["source_id"]:
            raise StateError("A single source cannot play both synthetic witness roles.")
        receipt = _json({"session": session_id, "revision": revision, "witnesses": sides})
        with self._write():
            session = self._owned(session_id, owner)
            previous = self._db.execute(
                "SELECT receipt FROM settlements WHERE id=?", (transaction_id,),
            ).fetchone()
            if previous:
                if previous["receipt"] != receipt:
                    raise StateError("A transaction identifier has conflicting settlement evidence.")
                return False
            self._require_active(session, now)
            current = self._input_row()
            if (session["revision"] != revision or session["counterparty"] is None
                    or session["input_revision"] != current["revision"]
                    or not current["captured"] <= now <= current["expires"]):
                raise StateError("Synthetic settlement requires matching current inputs and offer revision.")
            trade = self._db.execute(
                """SELECT payload, observed FROM events WHERE session=? AND revision=?
                   AND kind IN ('OFFER_OBSERVED', 'MAIN_OFFER_REVISION', 'PARTNER_OFFER_REVISION')""",
                (session_id, revision),
            ).fetchone()
            if trade is None:
                raise StateError("The synthetic settlement requires a recorded two-sided offer.")
            offer = json.loads(trade["payload"])
            give = _holdings(offer["give"], limit=PHYSICAL_SLOTS, max_quantity=COPIES_PER_SLOT_ASSUMPTION)
            receive = _holdings(offer["receive"], limit=PHYSICAL_SLOTS, max_quantity=COPIES_PER_SLOT_ASSUMPTION)
            if not give or not receive:
                raise StateError("Synthetic settlement requires a bilateral exchange with both sides present.")
            if (give.keys() & receive.keys()
                    or any(item.split(":", 1)[1].casefold() == "gingerscope" for item in give)):
                raise StateError("The synthetic offer conflicts with inventory protections.")
            prices = json.loads(current["prices"])
            if (give.keys() | receive.keys()) - prices.keys():
                raise StateError("Unknown item values preclude synthetic settlement accounting.")
            listed_delta = (sum(prices[key] * value for key, value in receive.items())
                            - sum(prices[key] * value for key, value in give.items()))
            if listed_delta < 0:
                raise StateError("Unapproved listed loss cannot enter synthetic settlement accounting.")
            accounts = json.loads(current["accounts"])
            account = session["account"]
            account_before = accounts[account]
            partner_before = json.loads(session["counterparty"])
            account_after = _after(account_before, give, receive)
            partner_after = _after(partner_before, receive, give)
            if any(sides[side]["before"] != before or sides[side]["after"] != after
                   for side, before, after in (
                       ("account", account_before, account_after),
                       ("counterparty", partner_before, partner_after),
                   )):
                raise StateError("The synthetic witnesses disagree with bilateral inventory conservation.")
            accounts[account] = account_after
            next_revision = self._put_inputs(current["market"], _json(accounts))
            evidence = {
                "scope": "synthetic", "evidence_class": _SETTLED, "revision": revision,
                "session_digest": _digest(session_id), "transaction_digest": _digest(transaction_id),
                "market_edition": current["market"],
                "offer_observed_at_utc": trade["observed"], "settled_at_utc": now,
                "listed_delta": listed_delta, "distinct_source_count": len(sides),
                "give_slots": len(give), "receive_slots": len(receive),
                "give_copies": sum(give.values()), "receive_copies": sum(receive.values()),
            }
            self._db.execute("INSERT INTO settlements VALUES (?, ?, ?, ?, ?, ?)",
                             (transaction_id, session_id, next_revision, receipt, _json(evidence), listed_delta))
            self._db.execute("UPDATE sessions SET phase='CLOSED', outcome=?, last_seen=? WHERE id=?",
                             (_SETTLED, now, session_id))
            return True

    def synthetic_settlement_rows(self):
        """Return identifier-minimized simulated outcomes for offline learning tests."""
        if self.scope != "synthetic":
            return []
        return [json.loads(row["evidence"]) for row in self._db.execute(
            "SELECT evidence FROM settlements ORDER BY resulting_revision, id"
        )]

    def summary(self):
        """Report local status without identifiers, decision payloads or holdings."""
        row = self._db.execute(
            """SELECT (SELECT max(revision) FROM inputs) AS input_revision,
               (SELECT count(*) FROM settlements) AS settlements,
               (SELECT sum(listed_delta) FROM settlements) AS sample_delta,
               sessions.outcome, count(sessions.id) AS total
               FROM (SELECT 1) LEFT JOIN sessions ON 1=1 GROUP BY sessions.outcome"""
        ).fetchall()
        counts = {item["outcome"]: item["total"] for item in row if item["outcome"] is not None}
        return {
            "schemaVersion": SCHEMA_VERSION, "scope": self.scope,
            "inputRevision": row[0]["input_revision"],
            "activeSessions": next((item["total"] for item in row if item["outcome"] is None), 0),
            "unresolvedSessions": sum(counts.get(outcome, 0) for outcome in _UNRESOLVED),
            "outcomeCounts": counts, "syntheticSettlements": row[0]["settlements"],
            "syntheticListedDelta": row[0]["sample_delta"], "realizedGrowth": None,
            "authoritativeSettlementVerified": False,
        }
