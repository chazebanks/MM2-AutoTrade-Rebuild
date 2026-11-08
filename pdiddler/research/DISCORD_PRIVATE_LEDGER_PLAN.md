# Discord evidence ledger — private GitHub storage, no Supabase dependency

## Current checkpoint (2026-11-08 UTC)

This document concerns the **separate Discord learner workstream** and does **not replace** the original Gingerscope Stage52→Stage53 plan. Once its private archive foundation and initial outcome-analysis capability are ready, **return immediately to Gingerscope Stage52's unmerged draft PR91** and proceed with Stage53 independently verified item identity, transaction result attribution, full trader integration and native tests. See the top of the three `GINGERSCOPE_*` handoffs.

### Verified evidence

- In the user's real Discord channel, the verified manual read-only audit parsed 57 messages: **30** test-account `venossgaming90190` notifications, **17** non-test internally consistent but **unverified** trade claims, **3** unparseable bundles requiring quarantine, **6** non-trade webhook messages, and **1** non-webhook.
- All 50 trade notification embeds used Discord embed **fields**, not description-only content. Only one distinct webhook ID observed; this is **not** yet an independently authenticated source identity.
- **Zero** server-confirmed settlements, **zero** learning-eligible records. Test-account transactions are excluded from real-trader analytics and any learning splits. No instrumented rejected offers, abandoned negotiations, or counterpart acceptance denominators exist yet.
- The user's existing Supabase project is healthy in the browser but linked ChatGPT Supabase connector reports permission denied. We are proceeding independently with GitHub storage.

### Critical repository privacy boundary

Both repositories currently exposed to the connected GitHub account, `chazebanks/MM2-AutoTrade-Rebuild` and `chazebanks/-MM2-AutoTrade`, are **PUBLIC**. Do **not** store a single real Discord message, bot token, trade archive, message ID index, trader username, or sensitive output in either repo, in their workflow artifacts, or in public logs.

This public repo may hold **source code, tests with synthetic data, and architecture documentation only**.

The user must create a **separate PRIVATE GitHub repository** (suggested name: `MM2-Trade-Research-Private`, initial private README) and enable GitHub Actions. There is no connected GitHub create-repository action here, so the user creates it in the GitHub UI, then the assistant can discover it if the GitHub app installation is granted access.

**Recommended private-repo workflow only (never run with private credentials in a public-repo workflow):**

1. In **private** repo Settings → Secrets and variables → Actions, create `MM2_RESEARCH_DISCORD_BOT_TOKEN` with the active research bot token; preferably rotate the token after moving it out of the public repo's secret scope and remove the obsolete public secret. Do not paste tokens in ChatGPT, workflow inputs, URLs or issue comments.
2. Add **one manually dispatched**, `main`-only, repository-private-only workflow. Give it `contents: write` only inside the private repo, `concurrency` to serialize historical imports, no `pull_request_target`, no PR secrets, no artifacts or raw message logging.
3. Check out the **private** repo and separately download the **reviewed, commit-SHA-pinned version** of these public research scripts (not a floating `main` branch):
   - `scripts/discord_history_embed_audit.py`
   - `scripts/discord_private_history_import.py`
4. Run in the **private** repo with `GITHUB_REPOSITORY`, `GITHUB_WORKSPACE` supplied by GitHub, `MM2_PRIVATE_REPO_VERIFIED=${{ github.event.repository.private }}`, `MM2_EXPECTED_ARCHIVE_REPO=${{ github.repository }}`, `MM2_RESEARCH_DISCORD_BOT_TOKEN=${{ secrets.MM2_RESEARCH_DISCORD_BOT_TOKEN }}`; invoke `python3 .../discord_private_history_import.py --channel-id <owner-approved channel ID>`.
5. The importer fails closed on public repo, missing private attestation, malformed pagination, unexpected item stacks/values, modified receipts, or incomplete fetch. It reads until the end within a 20×50 page maximum; no partial archive on truncation. It writes only to the private repo path `data/mm2_discord/history_v1.jsonl` after the full run succeeds.
6. If and only if the private archive file changes, commit only that file back into the **private** repo. The workflow should print aggregate safe counters only. Never expose source embeds, message IDs, trader labels or usernames in logs.
7. Review data access and retention. Separate the log of **historical webhook self-reports** from future **verified transaction evidence** and from **failed negotiation observations**. Avoid putting all three into an unqualified `completed_trades` table.

### Structured research-only record contract

Each stored row contains: message and channel reference, reported source webhook ID, optional Discord timestamp, parse classification, source-pin status, test-vs-other partner category, verified flags permanently false, and (when parseable and not a test alt) weapon **display labels** and **historic reported listed values**. It deliberately omits player usernames, message content, embed JSON and the bot token. Raw MM2 weapon IDs and Supreme checker identities remain **unverified**, and the claimed value gain is not independently settled profit.

For `venossgaming90190`, only the minimal test-account classification is retained. Unknown, ambiguous or unparseable receipts keep only their Discord message reference and quarantine reason; the original message can be re-fetched later if Discord has not deleted it. Do not silently drop those three.

The importer is idempotent. Repeated runs with identical receipts leave the archive unchanged. A previously indexed message with changed normalized content **fails** and requires human review instead of overwriting evidence. If the policy or source pin changes, plan a versioned migration rather than silently mutating existing records.

**No autonomous trading or adaptation:** These historical receipts do **not** train or authorize trades. Automatic final Accept, automatic listed-value losses, independent trade completion claims, and profit webhooks remain disabled. We still need future instrumentation of all offers, declines, timeouts, successful and unsuccessful counteroffers with actual denominators; statistically calibrated offline validation then explicit user authorization.

### Safety tests and immediate next action

Synthetic test suite in `pdiddler/intelligence_lab/test_discord_private_history_import.py` covers exact test-alt filtering, non-test exclusion mistakes, embed format and quantity ambiguities, value reconciliation, pagination, tampered evidence, idempotency, atomic writes, symlink rejection, public-repo guard, redacted log output and seeded random adversarial trials.

**Next user action after reviewed code merges:** Create a new **private** GitHub repo, then share only its `owner/repo` name, never its keys. We can create the private workflow there through the connected GitHub app after access is granted, pin the reviewed script SHA and perform the first guarded import. Do not claim any real data was archived until a successful private workflow and verified file counts.

### Return-to-Gingerscope condition

When we have a functional private archive of historical self-reports with test-alt exclusion and a research-only read/query path (no production learning), **end the side workstream**. Resume:
1. Validate current [Stage52 draft PR91](https://github.com/chazebanks/MM2-AutoTrade-Rebuild/pull/91), still unmerged at last inspection; preserve working `main` scheduled price refresh and guarded provenance.
2. Stage53 raw MM2 weapon key → checker ID/variant/year/copy identity research, exact source guards and offline tests.
3. Server-side trade outcome proof or defensible UNKNOWN classifications, safe accepted-state boundaries.
4. Bot-server detection, load readiness, scanner and request rotation, safe item placement/rebalancing integration, controlled iPad tests, learning shadow evaluation, and long-duration reliability.
