# KampusLink: read this first (every AI, every session)

KampusLink is a Flutter (Android first) + Supabase app for university students in Algeria.
Offline-first. Trilingual: Arabic (RTL), French, English. Pilot: Mining Engineering, year L2.

## Read in this order, before any code
1. `docs/MASTER_PLAN_V2.txt`: the plan, the lanes, the decisions. It wins over everything else.
2. `docs/CONTENT_FORMAT.txt`: lesson JSON, rendering rules (LaTeX, SVG, tables, highlights).
3. `docs/BACKEND_CONTRACT.txt`: the only backend calls you may use, and their error codes.
4. `docs/PROMPTS.txt`: your work-package prompt (P1..P13) and the session rules (P0).
5. `docs/logs/APP_LOG.txt` (last 20 entries) and `docs/logs/DECISIONS.txt` (OPEN items).

## Non-negotiable rules
- One lane, one work package, only your lane's folders (MASTER_PLAN section 5).
- The founder runs your PowerShell and pastes the output back. Small steps. Verify every step.
- Use the helpers: `. .\docs\tools\ps-helpers.ps1` (Write-Kampus, Replace-InFile, Step-Check, Step-Commit).
- Never put a secret in a command, a file or a chat. The app holds only the public anon key.
- Never touch Kampus Store tables/functions, `applicationId`, signing, or the `main` branch.
- No hard-coded text, colours, or left/right. Handle loading, empty, error, offline states.
- The app reads the local database; the network only syncs. Writes go through the contract's functions.
- A contract or plan change = a CORE CHANGE REQUEST in `docs/logs/DECISIONS.txt`, then wait for approval.
- End every session with an entry in `docs/logs/APP_LOG.txt`.

## Folders
- `backend/sql/` database history (Lane A only) | `fixtures/` sample content | `tools/content/` content tools (Lane C)
- `lib/app, lib/core` shell/theme/l10n/errors (B1) | `lib/data` db + sync (D1) | `lib/render` renderer (D2)
- `lib/features/*` screens by lane (see the plan) | `test/`, `integration_test/` tests
