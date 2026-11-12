"""Gingerscope durable PRIVATE research state, v1 (stdlib sqlite3).

No provider HTTP, Lua execution, price authority, final Accept or Discord.
Store only source-provenance metadata, CLIENT_ONLY inventory, and classified
non-settlement client events. A database is NOT proof of server trade settlement.
"""
from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
import tempfile
import re
import sqlite3
from pathlib import Path

SCHEMA = "gingerscope-private-state-v1"
KEY = re.compile(r"^[A-Za-z0-9_.:-]{1,96}$")
EVENT_KINDS = frozenset({
    "OFFER_OBSERVED", "COUNTEROFFER_OBSERVED", "OUR_DECLINE",
    "COUNTERPARTY_DECLINE_CLIENT", "PARTNER_LEFT_CLIENT", "CLOSED_UNKNOWN",
    "P3_REQUEST_IGNORED_CLIENT", "TRADE_WINDOW_OPEN_CLIENT",
})
MARKET_MODES = frozenset({"SYNTHETIC_OFFLINE_ONLY", "EXTERNAL_UNTRUSTED"})
DENIALS = {
    "sourceRightsVerified": False,
    "rawWeaponIdentityVerified": False,
    "verifiedRealMarketValue": False,
    "authorizesOffer": False,
    "authorizesAccept": False,
    "authorizesTrade": False,
    "autonomousLossAuthorized": False,
    "serverCompletionProven": False,
    "maySendDiscordWebhook": False,
    "mayUseForStrategyLearning": False,
    "mayReportProfit": False,
}

class InvalidEvidence(ValueError):
    pass

class ConflictingReplay(InvalidEvidence):
    pass

def ident(value: object) -> str:
    if type(value) is not str or KEY.fullmatch(value) is None:
        raise InvalidEvidence("INVALID_IDENTIFIER")
    return value

def clock(value: object) -> datetime:
    if type(value) is not str or not value.endswith("Z"):
        raise InvalidEvidence("UTC_TIMESTAMP_REQUIRED")
    try:
        d = datetime.fromisoformat(value[:-1] + "+00:00")
    except (ValueError, TypeError, OverflowError):
        raise InvalidEvidence("INVALID_TIMESTAMP") from None
    if d.utcoffset().total_seconds() != 0:
        raise InvalidEvidence("UTC_TIMESTAMP_REQUIRED")
    return d

def iso(d: datetime) -> str:
    return d.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")

def stable_json(obj: object) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True, allow_nan=False)

def digest(obj: object) -> str:
    return hashlib.sha256(stable_json(obj).encode("utf-8")).hexdigest()

def _exact(obj: object, keys: set[str]):
    if type(obj) is not dict or set(obj) != keys:
        raise InvalidEvidence("UNEXPECTED_OR_MISSING_FIELDS")

class Store:
    def __init__(self, filename: str | Path):
        self.filename = str(filename)
        self.db = sqlite3.connect(self.filename, timeout=15, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA busy_timeout=15000")
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        self._schema()

    def close(self):
        self.db.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    @contextmanager
    def _tx(self):
        self.db.execute("BEGIN IMMEDIATE")
        try:
            yield
            self.db.commit()
        except BaseException:
            self.db.rollback()
            raise

    def _schema(self):
        self.db.executescript("""
        CREATE TABLE IF NOT EXISTS schema_metadata (
            version INTEGER NOT NULL CHECK(version=1)
        );
        CREATE TABLE IF NOT EXISTS market_receipts (
            receipt_id TEXT PRIMARY KEY, source_id TEXT NOT NULL,
            observation_mode TEXT NOT NULL,
            source_published_at TEXT NOT NULL, retrieved_at TEXT NOT NULL,
            expires_at TEXT NOT NULL, item_count INTEGER NOT NULL,
            observation_sha256 TEXT NOT NULL,
            evidence_status TEXT NOT NULL CHECK(evidence_status='RESEARCH_ONLY')
        );
        CREATE TABLE IF NOT EXISTS inventory_checkpoints (
            checkpoint_id TEXT PRIMARY KEY, epoch_id TEXT NOT NULL,
            observed_at TEXT NOT NULL, payload_sha256 TEXT NOT NULL,
            items_json TEXT NOT NULL, evidence_status TEXT NOT NULL
                CHECK(evidence_status='CLIENT_ONLY')
        );
        CREATE TABLE IF NOT EXISTS client_trade_events (
            event_id TEXT PRIMARY KEY, epoch_id TEXT NOT NULL,
            revision INTEGER NOT NULL, kind TEXT NOT NULL,
            observed_at TEXT NOT NULL, content_sha256 TEXT NOT NULL,
            evidence_status TEXT NOT NULL CHECK(evidence_status='CLIENT_ONLY'),
            UNIQUE(epoch_id,revision,kind)
        );
        CREATE TABLE IF NOT EXISTS job_state (
            job_name TEXT PRIMARY KEY,
            next_run_at TEXT NOT NULL, interval_seconds INTEGER NOT NULL,
            lease_token TEXT, lease_until TEXT, last_result TEXT NOT NULL,
            CHECK(interval_seconds>=30)
        );
        CREATE INDEX IF NOT EXISTS idx_client_epoch
            ON client_trade_events(epoch_id, revision);
        """)
        row = self.db.execute("SELECT version FROM schema_metadata").fetchone()
        if row is None:
            self.db.execute("INSERT INTO schema_metadata(version) VALUES (1)")
        elif row["version"] != 1:
            raise InvalidEvidence("UNKNOWN_DATABASE_SCHEMA_VERSION")

    def backup_to(self, destination: str | Path) -> str:
        """Online consistent SQLite backup to a NEW private file, never overwrite.

        Backup remains private and client-only. Never upload or commit it to Git.
        A host must use a persistent encrypted directory and offsite retention.
        """
        if self.filename == ":memory:":
            raise InvalidEvidence("FILE_BACKUP_REQUIRES_DURABLE_SOURCE")
        target = Path(destination).resolve()
        source = Path(self.filename).resolve()
        if target == source or target.exists() or not target.parent.is_dir():
            raise InvalidEvidence("BACKUP_PATH_UNSAFE_OR_EXISTS")
        fd, tmpname = tempfile.mkstemp(
            prefix=".gingerscope-backup-", suffix=".part", dir=target.parent)
        os.close(fd)
        try:
            os.chmod(tmpname, 0o600)
            with sqlite3.connect(tmpname) as out:
                self.db.backup(out)
                check = out.execute("PRAGMA integrity_check").fetchone()[0]
                if check != "ok":
                    raise InvalidEvidence("BACKUP_INTEGRITY_FAILED")
            with open(tmpname, "rb") as checkfile:
                os.fsync(checkfile.fileno())
            # Hard-link exclusive create: never replace an existing backup,
            # even if another process writes the name while we were copying.
            os.link(tmpname, target)
            # Persist directory entry on POSIX hosts.
            try:
                directory_fd = os.open(str(target.parent), os.O_RDONLY)
                try:
                    os.fsync(directory_fd)
                finally:
                    os.close(directory_fd)
            except OSError:
                # FS behavior varies; host must separately verify durability.
                pass
            return "PRIVATE_BACKUP_CREATED_AND_INTEGRITY_CHECKED"
        except FileExistsError:
            raise InvalidEvidence("BACKUP_PATH_UNSAFE_OR_EXISTS") from None
        finally:
            try:
                os.unlink(tmpname)
            except FileNotFoundError:
                pass

    def record_market_receipt(self, data: dict, *, now: str) -> str:
        """Research metadata only. No raw prices, quote promotion or keys."""
        _exact(data, {"receiptId","sourceId","mode","sourcePublishedAt",
                      "retrievedAt","expiresAt","itemCount","observationSha256"})
        rid, source = ident(data["receiptId"]), ident(data["sourceId"])
        if data["mode"] not in MARKET_MODES:
            raise InvalidEvidence("UNTRUSTED_MARKET_MODE")
        start, received, expiry, observed = (
            clock(data["sourcePublishedAt"]), clock(data["retrievedAt"]),
            clock(data["expiresAt"]), clock(now)
        )
        if not start <= received <= observed or not start < expiry:
            raise InvalidEvidence("INVALID_SOURCE_CLOCK_ORDER")
        amount = data["itemCount"]
        if type(amount) is not int or not 0 <= amount <= 5000:
            raise InvalidEvidence("INVALID_MARKET_ITEM_COUNT")
        sha = data["observationSha256"]
        if type(sha) is not str or re.fullmatch(r"[0-9a-f]{64}", sha) is None:
            raise InvalidEvidence("INVALID_RESEARCH_HASH")
        canonical = (
            rid, source, data["mode"], iso(start), iso(received), iso(expiry),
            amount, sha, "RESEARCH_ONLY",
        )
        with self._tx():
            prev = self.db.execute("SELECT * FROM market_receipts WHERE receipt_id=?",(rid,)).fetchone()
            if prev:
                if tuple(prev) != canonical:
                    raise ConflictingReplay("CONFLICTING_MARKET_RECEIPT")
                return "DUPLICATE"
            self.db.execute(
                "INSERT INTO market_receipts VALUES (?,?,?,?,?,?,?,?,?)", canonical)
        return "STORED_RESEARCH_ONLY"

    def record_inventory(self, data: dict, *, now: str) -> str:
        """Store a client-only observation for continuity, not trusted holdings."""
        _exact(data, {"checkpointId","epochId","observedAt","items"})
        cid, epoch = ident(data["checkpointId"]), ident(data["epochId"])
        observed, local = clock(data["observedAt"]), clock(now)
        if observed > local:
            raise InvalidEvidence("FUTURE_CLIENT_OBSERVATION")
        items = data["items"]
        if type(items) is not list or len(items) > 1000:
            raise InvalidEvidence("INVALID_INVENTORY_SIZE")
        canonical_items, seen = [], set()
        for entry in items:
            _exact(entry, {"rawKey","copies"})
            k = ident(entry["rawKey"])
            n = entry["copies"]
            if k in seen or type(n) is not int or not 1 <= n <= 10000:
                raise InvalidEvidence("DUPLICATE_OR_INVALID_INVENTORY_COUNT")
            seen.add(k)
            canonical_items.append({"rawKey":k,"copies":n})
        canonical_items.sort(key=lambda x:x["rawKey"])
        payload = stable_json(canonical_items)
        row = (cid,epoch,iso(observed),digest(canonical_items),payload,"CLIENT_ONLY")
        with self._tx():
            prev = self.db.execute("SELECT * FROM inventory_checkpoints WHERE checkpoint_id=?",
                                   (cid,)).fetchone()
            if prev:
                if tuple(prev) != row:
                    raise ConflictingReplay("CONFLICTING_INVENTORY_CHECKPOINT")
                return "DUPLICATE"
            latest = self.db.execute(
                "SELECT observed_at FROM inventory_checkpoints "
                "ORDER BY observed_at DESC, checkpoint_id DESC LIMIT 1").fetchone()
            if latest and observed < clock(latest["observed_at"]):
                raise InvalidEvidence("STALE_INVENTORY_REPLAY")
            self.db.execute("INSERT INTO inventory_checkpoints VALUES (?,?,?,?,?,?)",row)
        return "STORED_CLIENT_ONLY"

    def record_trade_event(self, data: dict, *, now: str) -> str:
        """No settled/profit event can enter client-only stream."""
        _exact(data, {"eventId","epochId","revision","kind","observedAt"})
        eid, epoch = ident(data["eventId"]), ident(data["epochId"])
        kind = data["kind"]
        if type(kind) is not str or kind not in EVENT_KINDS:
            raise InvalidEvidence("UNVERIFIED_SETTLEMENT_EVENT_FORBIDDEN")
        revision = data["revision"]
        if type(revision) is not int or not 0 <= revision <= 1_000_000_000:
            raise InvalidEvidence("INVALID_REVISION")
        observed, local = clock(data["observedAt"]), clock(now)
        if observed > local:
            raise InvalidEvidence("FUTURE_CLIENT_EVENT")
        canonical = (eid,epoch,revision,kind,iso(observed),digest(data),"CLIENT_ONLY")
        with self._tx():
            prev = self.db.execute(
                "SELECT * FROM client_trade_events WHERE event_id=?", (eid,)
            ).fetchone()
            if prev:
                if tuple(prev) != canonical:
                    raise ConflictingReplay("CONFLICTING_TRADE_EVENT")
                return "DUPLICATE"
            latest = self.db.execute(
                "SELECT MAX(revision) AS rev FROM client_trade_events WHERE epoch_id=?",
                (epoch,)).fetchone()["rev"]
            if latest is not None and revision < latest:
                raise InvalidEvidence("STALE_EPOCH_REVISION")
            try:
                self.db.execute("INSERT INTO client_trade_events VALUES (?,?,?,?,?,?,?)", canonical)
            except sqlite3.IntegrityError:
                raise ConflictingReplay("COLLIDING_EPOCH_REVISION_KIND") from None
        return "STORED_CLIENT_ONLY"

    def prepare_health_job(self, *, now: str, interval_seconds: int = 3600):
        t = iso(clock(now))
        if type(interval_seconds) is not int or not 30 <= interval_seconds <= 86400:
            raise InvalidEvidence("INVALID_HEALTH_INTERVAL")
        with self._tx():
            self.db.execute(
                "INSERT OR IGNORE INTO job_state VALUES (?,?,?,?,?,?)",
                ("local_health",t,interval_seconds,None,None,"NOT_RUN")
            )

    def claim_health_job(self, *, token: str, now: str, lease_seconds: int = 120) -> bool:
        """Atomic across simultaneous workers. No market polling allowed."""
        ident(token)
        if type(lease_seconds) is not int or not 10 <= lease_seconds <= 600:
            raise InvalidEvidence("INVALID_LEASE")
        instant = clock(now)
        until = iso(datetime.fromtimestamp(
            instant.timestamp()+lease_seconds, tz=timezone.utc))
        with self._tx():
            row = self.db.execute(
                "SELECT * FROM job_state WHERE job_name='local_health'").fetchone()
            if not row or clock(row["next_run_at"]) > instant:
                return False
            if row["lease_until"] and clock(row["lease_until"]) > instant:
                return False
            self.db.execute(
                "UPDATE job_state SET lease_token=?,lease_until=? WHERE job_name='local_health'",
                (token,until))
        return True

    def finish_health_job(self, *, token: str, now: str) -> bool:
        instant = clock(now)
        with self._tx():
            row = self.db.execute(
                "SELECT * FROM job_state WHERE job_name='local_health'").fetchone()
            if not row or row["lease_token"] != ident(token) or (
                row["lease_until"] and clock(row["lease_until"]) < instant
            ):
                return False
            future = iso(datetime.fromtimestamp(
                instant.timestamp()+row["interval_seconds"],tz=timezone.utc))
            self.db.execute(
                "UPDATE job_state SET next_run_at=?,lease_token=NULL,lease_until=NULL,"
                "last_result='OK_PRIVATE_LOCAL' WHERE job_name='local_health'",
                (future,))
        return True

    def safe_status(self, *, now: str) -> dict:
        t = clock(now)
        market = self.db.execute(
            "SELECT * FROM market_receipts ORDER BY retrieved_at DESC, receipt_id DESC LIMIT 1"
        ).fetchone()
        inventory = self.db.execute(
            "SELECT * FROM inventory_checkpoints ORDER BY observed_at DESC,checkpoint_id DESC LIMIT 1"
        ).fetchone()
        count = self.db.execute("SELECT COUNT(*) FROM client_trade_events").fetchone()[0]
        health = self.db.execute(
            "SELECT last_result FROM job_state WHERE job_name='local_health'"
        ).fetchone()
        market_status = "UNAVAILABLE"
        if market is not None:
            market_status = "RESEARCH_ONLY_UNEXPIRED" if clock(market["expires_at"]) > t else "STALE_RESEARCH"
        return {
            "schema":SCHEMA,
            "marketStatus":market_status,
            "marketSourceProvenance":"NOT_AUTHENTICATED",
            "marketPriceDataExposed":False,
            "inventoryCheckpointStatus":"CLIENT_ONLY" if inventory else "NONE",
            "observedTradeEventsClientOnly":count,
            "confirmedSettledTrades":0,
            "serverSettlementStatus":"UNKNOWN",
            "healthJobStatus":health["last_result"] if health else "NOT_CONFIGURED",
            "plannerMode":"BLOCKED_READ_ONLY",
            "protectedOutboundItem":"Gingerscope",
            **DENIALS,
        }
