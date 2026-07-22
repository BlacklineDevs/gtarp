# PALM6 Threads — Phase 1: Curated Core Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This plan spans TWO repos — every `palm6-web` file path is marked **[VERIFY AT EXECUTION]** because that repo is NOT checked out in this worktree; Task 1 is a mandatory recon gate that confirms those paths before any code is written.

**Goal:** Ship the first end-to-end player-created-clothing loop, **curated mode only, perk-gated, prod-inert**: a slot ledger in the shared game DB grants a player a design slot from a perk/role; the player designs a curated color+decal texture in `palm6-web /dashboard/threads`; the design lands in an admin queue at `palm6-web /admin/threads`; on approval it is allocated a stable, reserved drawable index and marked deliverable; the FiveM `palm6_threads` resource reads that player's deliverable designs by `citizenid` and equips them via `illenium-appearance`. Every new surface ships gated OFF; nothing is player-facing until David flips it after an in-game verification.

**Architecture:** The **shared game DB is the seam** — `palm6-web` writes `palm6_clothing_*`; the `palm6_threads` game resource reads. Same pattern as `palm6_business`. Phase 1 covers four subsystems: (1) **entitlement slot ledger** (new tables via `palm6_dbmigrate`; perk/role grantor only — the Tebex grantor is a Phase 2 seam), (2) **curated web editor** (color+decal library we control → one flattened texture PNG to storage + a `designs` row; the only Phase 1 input mode because it needs no heavy moderation), (3) **admin approval queue** (staff approve/reject with reason; approval allocates a stable index), and (4) the **FiveM equip path** (read deliverable designs by `citizenid`, apply `{component, drawable, texture}` through illenium persistence). The equip path is **abstracted over the physical asset-delivery mechanism** (Stage A replacement vs. Stage B addon-DLC): it applies whatever indices a deliverable `designs` row declares and does not care how the `.ytd` reached `stream/`. The automated binary generator (Stage B) that produces and commits those `.ytd`/`.ydd`/`.ymt` assets is **explicitly out of scope** (gated on an in-game render test that has not passed) — Phase 1 stops the automated chain at `approved` and exposes a clean, staff-driven `approved → deliverable` seam so the loop is demonstrable using the Phase-0-proven Stage A asset.

**Tech Stack:**
- **Shared game DB** (MariaDB/MySQL via oxmysql): new `palm6_clothing_*` tables added to `palm6_dbmigrate`'s hardcoded idempotent statement list (currently at migration `0073`; Phase 1 adds `0074`).
- **palm6-web** (Next.js App Router, TypeScript, Discord OAuth, connects to the game DB via `GTARP_DB_*`): new `src/lib/threads/*` service layer, `/dashboard/threads` editor, `/admin/threads` queue, `/api/threads/*` route handlers. Unit tests follow `src/lib/auth/session.test.ts` conventions. **All palm6-web paths are [VERIFY AT EXECUTION].**
- **palm6_threads FiveM resource** (Lua, this worktree, `resources/[custom]/palm6_threads`): evolves the Stage A spike into a server-read + client-equip resource with a framework bridge (`qbx_core`) and an illenium-appearance game adapter. Ships `Config.Enabled = false`.

## Global Constraints

- **Inert-first (hard):** every new surface — web routes, API handlers, the game resource — ships gated OFF. `palm6_threads` keeps `Config.Enabled = false`; web routes ship behind a feature flag / role gate that is dark by default. NO player-facing change until David explicitly flips it after the Task 9 in-game gate. The deploy is the boot-verify; a flip is a separate, gated act.
- **Index stability (hard invariant):** drawable indices are reserved and **never reused**. `palm6_clothing_slots_alloc` is the persistent allocator (`UNIQUE(component_id, drawable_index)`); an approved design is assigned a fixed index that is never renumbered and never reclaimed on revoke. Reusing an index corrupts every saved outfit (illenium saves by `{component, drawable, texture}`).
- **IP is existential:** Take-Two owns Cfx.re and can pull the server key + Tebex store over ripped/real-brand/copyrighted assets. Phase 1 accepts **curated input ONLY** — colors + decals/text from a pre-vetted library we control — precisely because it needs no heavy vision moderation. Uploads and AI-gen (which do) are Phases 3–4 and MUST NOT be built here. Still lint curated text for slurs.
- **Shared-DB seam:** all new tables land via `palm6_dbmigrate` only, as `IF NOT EXISTS`/idempotent statements appended to the hardcoded list. **NEVER `prisma db push` against the game DB.** The game DB is shared across ~60 worktrees — coordinate the `0074` add so it does not collide (same discipline as the records-hub `db push` hold). palm6-web owns writes to `garments/slots/designs/jobs/slots_alloc`; the game resource **reads only** and never writes economy-owned tables.
- **Delivery-mechanism abstraction:** the game resource applies indices from a deliverable `designs` row; it MUST NOT hardcode whether the asset arrived as a Stage A base-drawable replacement or a Stage B addon-DLC. The `garment_id → {component_id, drawable band}` mapping lives in `Config`; the physical `.ytd` presence is the pipeline's concern, not the resource's.
- **FiveM conventions:** `CancelEvent()` before ANY yield in an event handler; every `.lua` must be `luaparse`-clean; net events DoS-budgeted in `palm6_eventguard`; NO local FXServer exists — **the deploy IS the boot-verify** (FiveM drops erroring resources, so LOADED = clean-booted). Debug/admin commands are ace-gated, never open net events. Framework calls isolated in a `bridge/` adapter (the `palm6_business`/`palm6_gangs` pattern) so a GTA VI port is a bridge rewrite.
- **Bash hangs on this box** — use PowerShell for all git/shell. Paths containing `[custom]` are literal brackets — use `-LiteralPath` in PowerShell.
- **Out of scope (do NOT build):** Tebex webhook + monetization (Phase 2 — leave the `slots.source='tebex'` seam, build nothing); upload/AI input modes + vision moderation (Phases 3–4); three.js 3D preview (Phase 4); the Stage B binary addon-DLC generator + GitHub Actions generation worker (gated on the un-passed in-game render test — leave the `approved → deliverable` seam, build no packer).

---

## File Structure

**palm6-web (all paths [VERIFY AT EXECUTION] — confirmed/corrected in Task 1):**

| File | Status | Responsibility (one each) |
|------|--------|---------------------------|
| `src/lib/data/citizen.ts` | reuse | Existing `discord → citizenid` resolver (`users.discord → users.userId → players.userId → players.citizenid`). Consumed, not modified. |
| `src/lib/db/gtarp.ts` (name TBD) | reuse | Existing `GTARP_DB_*` game-DB client. Consumed by all `src/lib/threads/*`. |
| `src/lib/auth/roles.ts` (name TBD) | reuse | Existing Discord role gating (`DISCORD_ROLE_*`) — founder/business-owner/donor + mod/admin checks. |
| `src/lib/storage/*.ts` (name TBD) | reuse | Existing storage helper behind the gang-logo image precedent. Consumed by the editor to persist texture PNGs. |
| `src/lib/threads/db.ts` | create | Typed CRUD queries against `palm6_clothing_*` (the ONLY module issuing SQL for Threads). |
| `src/lib/threads/catalog.ts` | create | Curated garment catalog + the pre-vetted color/decal/text library definitions (server-owned; the abuse boundary for what a curated design may contain). |
| `src/lib/threads/entitlement.ts` | create | Slot ledger: perk/role grant (idempotent), consume-on-start, refund-on-reject, in-flight cap. Tebex grant is a stubbed seam. |
| `src/lib/threads/designs.ts` | create | Design lifecycle state machine (`draft→submitted→approved/rejected→deliverable`) + stable-index allocation on approval. |
| `src/lib/threads/entitlement.test.ts` | create | Unit tests: grant idempotency, consume/refund, cap enforcement. |
| `src/lib/threads/designs.test.ts` | create | Unit tests: legal/illegal transitions, allocator never reuses an index, curated-text slur lint. |
| `src/app/dashboard/threads/page.tsx` (+ components) | create | Curated editor UI: pick garment → colors/decals/text from the library → 2D UV composite preview → submit. Role+slot gated; dark by default. |
| `src/app/api/threads/designs/route.ts` (+ `[id]`) | create | Design create/submit/list handlers (consume a slot on create; compose + persist the texture PNG). |
| `src/app/admin/threads/page.tsx` (+ actions) | create | Staff queue: list pending, preview, approve (allocate index + mark deliverable) / reject (refund + reason). Mod/admin gated. |

**palm6_threads FiveM resource (this worktree — concrete paths):**

| File | Status | Responsibility |
|------|--------|----------------|
| `resources/[custom]/palm6_dbmigrate/server.lua` | modify | Append `0074 palm6_clothing_*` idempotent `CREATE TABLE IF NOT EXISTS` statements to the hardcoded list. |
| `resources/[custom]/palm6_threads/fxmanifest.lua` | modify | Add `server_script`, `bridge/sv_framework.lua`, `bridge/cl_game.lua`, `client/main.lua`; declare `oxmysql` dependency. Keep Stage A stream note. |
| `resources/[custom]/palm6_threads/shared/config.lua` | modify | `Config.Enabled = false`; `Config.Garments` map (`garment_id → {component_id, drawable band}`); reserved-index band constants. |
| `resources/[custom]/palm6_threads/bridge/sv_framework.lua` | create | Server framework adapter: `Bridge.GetCitizenId(src)`, `Bridge.Notify`, presence — isolates `qbx_core` (the business/gangs pattern). |
| `resources/[custom]/palm6_threads/server/main.lua` | create | Read deliverable designs for a `citizenid` from `palm6_clothing_designs` (status filter, read-only); serve them to that player's client. `CancelEvent()`-clean; DoS-budgeted. |
| `resources/[custom]/palm6_threads/bridge/cl_game.lua` | create | Client game adapter: `Game.GetAppearance/SetAppearance` wrapping illenium `getPedAppearance`/`setPedAppearance`; `Game.ApplyComponent` wrapping `SetPedComponentVariation`. |
| `resources/[custom]/palm6_threads/client/main.lua` | create | Equip owned deliverable designs by writing `{component, drawable, texture}` into the illenium saved skin so it re-applies on spawn; `/threads` wardrobe to equip/unequip. Inert while `Config.Enabled=false`. |
| `resources/[custom]/palm6_threads/client/debug.lua` | delete | Retire the Stage A spike command (replaced by the real equip path). |

---

### Task 1: Verify palm6-web paths + patterns (recon gate — BLOCKS all web tasks)

**Files:**
- Create: `docs/superpowers/plans/notes/phase1-palm6-web-verification.md` (records confirmed/corrected paths + interface signatures)

**Interfaces:**
- Produces: a verification note mapping every **[VERIFY AT EXECUTION]** path to its real path + the actual exported signature. Consumed by Tasks 3–7.

> palm6-web is NOT in this worktree. Do this recon in the palm6-web checkout (ask David for its path if unknown) before writing any web code. Do NOT invent internals — confirm them.

- [ ] **Step 1: Confirm the discord→citizenid resolver**

Open `src/lib/data/citizen.ts`. Record the exact exported function name + signature (e.g. `getCitizenIdByDiscord(discordId: string): Promise<string | null>`) and the DB it queries.

- [ ] **Step 2: Confirm the game-DB client**

Find the module that connects with `GTARP_DB_*` env (grep `GTARP_DB_`). Record its path + the query API (pooled client? tagged-template? a `query()` helper?). This is what `src/lib/threads/db.ts` will import.

- [ ] **Step 3: Confirm role gating + admin gating**

Find the role helper using `DISCORD_ROLE_*` (grep `DISCORD_ROLE_`). Record: how a session's roles are read, the helper that asserts a role, and how the existing `/admin/whitelist` + `/admin/players` pages gate to mod/admin. Record the founder/business-owner/donor role identifiers available.

- [ ] **Step 4: Confirm the storage helper (gang-logo precedent)**

Find how gang logos are persisted (grep `logo_url` / storage). Record the upload/persist helper signature + where the public URL comes from. This is the texture-PNG persistence path for the editor.

- [ ] **Step 5: Confirm test + dashboard-route conventions**

Open `src/lib/auth/session.test.ts` (test runner, mocking style, DB-mock pattern) and one existing `src/app/dashboard/*` route (auth gating, layout). Record the conventions the new tests + routes must follow.

- [ ] **Step 6: Write the verification note + reconcile the File Structure**

Write `phase1-palm6-web-verification.md` with a table: planned path → confirmed path → exported signature. For every mismatch, note the correction the later tasks must use. Commit.

```powershell
Push-Location 'C:\Users\Mgtda\Projects\Active\gtarp-threads'
git add "docs/superpowers/plans/notes/phase1-palm6-web-verification.md"
git commit -m @'
docs(threads): Phase 1 palm6-web path/pattern verification note (Task 1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
'@
Pop-Location
```

---

### Task 2: Shared game DB migration — `palm6_clothing_*` tables (via palm6_dbmigrate)

**Files:**
- Modify: `resources/[custom]/palm6_dbmigrate/server.lua` (append `0074` statements)

**Interfaces:**
- Produces: five idempotent tables on boot — `palm6_clothing_garments`, `palm6_clothing_slots`, `palm6_clothing_designs`, `palm6_clothing_slots_alloc`, `palm6_clothing_jobs` (schema per spec §6). All `CREATE TABLE IF NOT EXISTS`; first-boot-safe (no mass back-grant).
- Consumes: nothing (DDL only).

- [ ] **Step 1: Append the `0074` statements to the `STATEMENTS` list**

Add five entries to the hardcoded `STATEMENTS` table in `server.lua`, immediately before the closing `}`, each `{ name = '0074 ...', sql = [[ ... ]] }`, following the exact idempotent/`IF NOT EXISTS` + `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4` convention already in the file. Columns per spec §6:

- `palm6_clothing_garments` — `id INT UNSIGNED PK AUTO_INCREMENT, label VARCHAR(64), category VARCHAR(24), gender VARCHAR(8), component_id TINYINT UNSIGNED, base_ydd_ref VARCHAR(128), uv_template_ref VARCHAR(128), uv_resolution SMALLINT UNSIGNED, enabled TINYINT(1) NOT NULL DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`.
- `palm6_clothing_slots` — `id INT UNSIGNED PK AUTO_INCREMENT, citizenid VARCHAR(64) NOT NULL, source ENUM('tebex','perk','admin') NOT NULL, source_ref VARCHAR(128) NULL, granted_at BIGINT UNSIGNED NOT NULL, consumed_by_design_id INT UNSIGNED NULL, revoked TINYINT(1) NOT NULL DEFAULT 0, INDEX idx_clothing_slots_cid (citizenid), UNIQUE KEY uniq_clothing_slot_source (source, source_ref, citizenid)` (the UNIQUE makes perk/role grant idempotent — re-running the sync never double-grants the same role).
- `palm6_clothing_designs` — `id INT UNSIGNED PK AUTO_INCREMENT, citizenid VARCHAR(64) NOT NULL, garment_id INT UNSIGNED NOT NULL, source_mode ENUM('curated','upload','ai') NOT NULL DEFAULT 'curated', texture_ref VARCHAR(256) NULL, status ENUM('draft','submitted','mod_pending','approved','rejected','generating','deployed','failed') NOT NULL DEFAULT 'draft', moderation_json JSON NULL, staff_reviewer VARCHAR(64) NULL, reject_reason VARCHAR(255) NULL, drawable_index INT NULL, texture_index INT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, INDEX idx_clothing_designs_cid_status (citizenid, status)` (the compound index backs the game resource's by-citizenid deliverable read).
- `palm6_clothing_slots_alloc` — `component_id TINYINT UNSIGNED NOT NULL, drawable_index INT NOT NULL, design_id INT UNSIGNED NOT NULL, allocated_at BIGINT UNSIGNED NOT NULL, PRIMARY KEY (component_id, drawable_index)` (the PK enforces the never-reused-index invariant at the DB level).
- `palm6_clothing_jobs` — `id INT UNSIGNED PK AUTO_INCREMENT, design_id INT UNSIGNED NOT NULL, status ENUM('queued','running','done','failed') NOT NULL DEFAULT 'queued', attempts INT UNSIGNED NOT NULL DEFAULT 0, worker_run_id VARCHAR(64) NULL, error VARCHAR(512) NULL, artifact_ref VARCHAR(256) NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, INDEX idx_clothing_jobs_design (design_id)` (present now for the Phase-2/Stage-B seam; Phase 1 writes no rows here).

- [ ] **Step 2: luaparse-clean the migration file**

```powershell
Push-Location 'C:\Users\Mgtda\Projects\Active\gtarp-threads\resources\[custom]\palm6_dbmigrate'
npx --yes luaparse server.lua 2>&1
Pop-Location
```
Expected: no parse errors. (If `npx` hangs on this box, read-verify the appended block: balanced `[[ ]]`, trailing commas between entries, closing `}` intact.)

- [ ] **Step 3: Verify idempotency by inspection**

Confirm every statement is `CREATE TABLE IF NOT EXISTS` (no bare `CREATE`, no `DROP`, no data `INSERT`), so a re-run on the shared DB is a harmless no-op and the ~60-worktree coordination risk is bounded to "the table appears once."

- [ ] **Step 4: Commit**

```powershell
Push-Location 'C:\Users\Mgtda\Projects\Active\gtarp-threads'
git add "resources/[custom]/palm6_dbmigrate/server.lua"
git commit -m @'
feat(threads): 0074 palm6_clothing_* shared-DB tables via palm6_dbmigrate (Phase 1 Task 2)

Idempotent CREATE TABLE IF NOT EXISTS for garments/slots/designs/slots_alloc/jobs.
slots_alloc PK enforces never-reused drawable index; slots UNIQUE makes perk grant
idempotent. First-boot-safe (no back-grant). Web owns writes; game resource reads.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
'@
Pop-Location
```

---

### Task 3: Curated catalog + library (palm6-web `src/lib/threads/catalog.ts`)

**Files:**
- Create: `src/lib/threads/catalog.ts` **[VERIFY AT EXECUTION]**
- Create: `src/lib/threads/db.ts` **[VERIFY AT EXECUTION]** (the ONLY Threads SQL module)
- Create/seed: `palm6_clothing_garments` rows (seed via `db.ts`, run once — NOT via `prisma db push`)

**Interfaces:**
- Consumes: the game-DB client confirmed in Task 1 Step 2.
- Produces:
  - `db.ts`: `getGarment(id: number): Promise<Garment | null>`, `listEnabledGarments(): Promise<Garment[]>`, plus typed slot/design/alloc CRUD used by later tasks (`insertSlot`, `getGrantedUnconsumedSlot`, `consumeSlot`, `refundSlot`, `insertDesign`, `getDesign`, `listDesignsByStatus`, `updateDesignStatus`, `allocateDrawableIndex`).
  - `catalog.ts`: `CURATED_LIBRARY` (server-owned set of allowed colors, decals, text-fonts with their UV placement rules) + `validateCuratedSpec(spec): { ok: true } | { ok: false, reason }` (rejects any decal/color/text not in the vetted library; lints text for slurs). `type Garment = { id, label, category, gender, componentId, baseYddRef, uvTemplateRef, uvResolution, enabled }`.

- [ ] **Step 1: Write a failing test for `validateCuratedSpec`**

`src/lib/threads/catalog.test.ts`: assert an in-library spec passes; a decal id not in `CURATED_LIBRARY` fails with reason; a text field containing a slur (use a mild fixture) fails. Run — expect failure (module absent).

- [ ] **Step 2: Implement `catalog.ts`**

Define `CURATED_LIBRARY` (the abuse boundary: only these colors/decals/fonts are legal input) and `validateCuratedSpec`. This is the IP defense — a curated design can only reference pre-vetted assets, so no moderation queue is needed. Run the test — expect pass.

- [ ] **Step 3: Implement `db.ts` typed queries + seed the garment catalog**

Implement the query functions above against the Task-1 client. Seed 3–5 curated base garments (e.g. male/female torso `component_id=11`) into `palm6_clothing_garments` via a one-shot `db.ts` seed call (idempotent on `label`). Record the seed invocation in the verification note.

- [ ] **Step 4: Run the suite; commit**

Run the Threads test file green. Commit `catalog.ts`, `catalog.test.ts`, `db.ts`, and the seed in the palm6-web repo (its commit conventions; the co-author trailer applies). Record the palm6-web commit hash in the verification note so this plan's summary can reference it.

---

### Task 4: Entitlement slot ledger (palm6-web `src/lib/threads/entitlement.ts`)

**Files:**
- Create: `src/lib/threads/entitlement.ts` **[VERIFY AT EXECUTION]**
- Create: `src/lib/threads/entitlement.test.ts` **[VERIFY AT EXECUTION]**

**Interfaces:**
- Consumes: `db.ts` (Task 3), `citizen.ts` resolver + role helper (Task 1).
- Produces:
  - `syncPerkGrants(discordId): Promise<{ granted: number }>` — resolves discord→citizenid, reads founder/business-owner/donor roles, inserts `slots` rows `source='perk', source_ref=<roleId>` **idempotently** (the `uniq_clothing_slot_source` UNIQUE guarantees no double-grant on re-sync).
  - `consumeSlotForDesign(citizenid, designId): Promise<{ ok: boolean }>` — claims one granted, unconsumed, unrevoked slot (`consumed_by_design_id = designId`) atomically; enforces the in-flight cap (max concurrent non-terminal designs per player).
  - `refundSlotForDesign(designId): Promise<void>` — nulls `consumed_by_design_id` for a rejected design's slot.
  - `grantTebexSlot(...)` — **stub that throws `NotImplemented` (Phase 2 seam)**; documented, not wired.

- [ ] **Step 1: Write failing tests**

`entitlement.test.ts` (mock `db.ts` per the Task-1 test convention): (a) `syncPerkGrants` called twice grants once (idempotent); (b) `consumeSlotForDesign` succeeds when a free slot exists, fails when none; (c) the in-flight cap blocks an over-cap consume; (d) `refundSlotForDesign` frees the slot for reuse. Run — expect failure.

- [ ] **Step 2: Implement `entitlement.ts`**

Implement grant/consume/refund/cap against `db.ts`. Slots are the scarce, server-granted resource — the abuse boundary that stops editor/pipeline spam. Leave `grantTebexSlot` a documented `NotImplemented` stub. Run tests — expect green.

- [ ] **Step 3: Commit**

Commit in palm6-web; record the hash in the verification note.

---

### Task 5: Design lifecycle + stable-index allocator (palm6-web `src/lib/threads/designs.ts`)

**Files:**
- Create: `src/lib/threads/designs.ts` **[VERIFY AT EXECUTION]**
- Create: `src/lib/threads/designs.test.ts` **[VERIFY AT EXECUTION]**

**Interfaces:**
- Consumes: `db.ts`, `entitlement.ts`, `catalog.ts`.
- Produces:
  - `createDraft(citizenid, garmentId, curatedSpec): Promise<{ designId }>` — validates the spec (`validateCuratedSpec`), consumes a slot, inserts a `designs` row `status='draft', source_mode='curated'`.
  - `submitDesign(designId): Promise<void>` — `draft → submitted`. Curated designs skip heavy moderation (spec §9) → policy: transition straight to `approved` OR to a light staff gate, per the confirmed decision (see Open Question O1); default to a light staff gate (`submitted`, appears in the admin queue).
  - `approveDesign(designId, staffId): Promise<{ drawableIndex, textureIndex }>` — `submitted → approved`, then **allocates a stable index**: pick the lowest free `drawable_index` in the garment's reserved band, insert into `palm6_clothing_slots_alloc` (PK collision = already allocated, retry next), write `drawable_index`/`texture_index` back onto the design.
  - `markDeliverable(designId): Promise<void>` — `approved → deployed` (the Phase-1 staff-driven seam standing in for the Stage B worker; see Global Constraints).
  - `rejectDesign(designId, staffId, reason): Promise<void>` — `→ rejected` + `refundSlotForDesign`.
  - `assertTransition(from, to)` — the single source of truth for legal edges.

- [ ] **Step 1: Write failing tests**

`designs.test.ts`: (a) every legal edge allowed, every illegal edge (e.g. `rejected → approved`, `draft → deployed`) throws; (b) `approveDesign` allocates a fixed index and a **second** approval never reuses a freed/revoked index (drive the allocator with a pre-seeded `slots_alloc` row and assert the PK-collision retry advances); (c) `createDraft` rejects an out-of-library curated spec; (d) `rejectDesign` refunds the slot. Run — expect failure.

- [ ] **Step 2: Implement `designs.ts`**

Implement the state machine + allocator. Enforce index stability: allocation is append-only within the garment's reserved band, never reclaimed on reject/revoke (simplicity over reclaim, per spec §5.4). Run tests — expect green.

- [ ] **Step 3: Commit**

Commit in palm6-web; record the hash.

---

### Task 6: Curated web editor + API (palm6-web `/dashboard/threads`)

**Files:**
- Create: `src/app/dashboard/threads/page.tsx` (+ editor components) **[VERIFY AT EXECUTION]**
- Create: `src/app/api/threads/designs/route.ts` (+ `[id]/route.ts`) **[VERIFY AT EXECUTION]**

**Interfaces:**
- Consumes: `designs.ts`, `catalog.ts`, `entitlement.ts`, the storage helper (Task 1 Step 4), session/role gating (Task 1 Step 3).
- Produces:
  - `POST /api/threads/designs` → `createDraft` (consumes a slot) + composes the curated spec into a flattened texture PNG at the garment's `uv_resolution` and persists it via the storage helper (writes `texture_ref`). Returns `{ designId, previewUrl }`.
  - `POST /api/threads/designs/[id]/submit` → `submitDesign`.
  - `GET /api/threads/designs` → the caller's designs + slot balance.
  - `/dashboard/threads` page: role+slot gated (dark by default via feature flag); flow = pick garment → choose colors/decals/text from the library → 2D UV-template composite preview → submit. Follows the palm6-web dark-mode design system.

- [ ] **Step 1: Server-side gate + slot-consume path first**

Implement `POST /api/threads/designs` with the role gate, slot consume, `validateCuratedSpec`, PNG compose, storage persist, `createDraft`. Add a route-level test (Task-1 convention): unauthenticated → 401; no free slot → 402/409 (no design row created); valid → a `designs` row + a persisted `texture_ref`. Run green.

- [ ] **Step 2: Submit + list endpoints**

Implement `[id]/submit` and `GET`. Test the happy path + that a non-owner cannot submit another player's design (authority is server-side by `citizenid`, never client-asserted). Run green.

- [ ] **Step 3: Editor UI behind the feature flag**

Build `page.tsx` + components: garment picker, curated controls (only library colors/decals/fonts), 2D composite preview, submit. Gate the route dark by default (feature flag OFF). Verify the 5 data states (loading/empty/error/success/retry) per the palm6-web empty-state discipline.

- [ ] **Step 4: Commit**

Commit in palm6-web; record the hash.

---

### Task 7: Admin approval queue (palm6-web `/admin/threads`)

**Files:**
- Create: `src/app/admin/threads/page.tsx` (+ approve/reject server actions) **[VERIFY AT EXECUTION]**

**Interfaces:**
- Consumes: `designs.ts` (`approveDesign`, `markDeliverable`, `rejectDesign`), mod/admin gating (Task 1 Step 3), the storage preview URL.
- Produces:
  - Queue page listing `submitted` designs with the composed preview + garment + player.
  - `approve` action → `approveDesign` (allocate index) then `markDeliverable` (`→ deployed`) — Phase 1 does this in one staff click (the Stage B worker will later split these: approve → dispatch → generate → deliverable). Full audit (`staff_reviewer`, timestamps).
  - `reject` action → `rejectDesign(reason)` (refund + reason). Mirrors `/admin/whitelist` + `/admin/players`. Mod/admin gated; dark by default.

- [ ] **Step 1: Server actions first, with a gate test**

Implement `approve`/`reject` server actions with the mod/admin gate. Test: a non-admin session cannot approve; approve moves `submitted → deployed` with an allocated index + recorded `staff_reviewer`; reject refunds the slot and stores the reason. Run green.

- [ ] **Step 2: Queue UI**

Build `page.tsx`: list, preview, approve/reject-with-reason. Empty/loading/error states. Dark by default.

- [ ] **Step 3: Commit**

Commit in palm6-web; record the hash.

---

### Task 8: FiveM `palm6_threads` — read deliverable designs + equip via illenium (this worktree)

**Files:**
- Modify: `resources/[custom]/palm6_threads/fxmanifest.lua`
- Modify: `resources/[custom]/palm6_threads/shared/config.lua`
- Create: `resources/[custom]/palm6_threads/bridge/sv_framework.lua`
- Create: `resources/[custom]/palm6_threads/server/main.lua`
- Create: `resources/[custom]/palm6_threads/bridge/cl_game.lua`
- Create: `resources/[custom]/palm6_threads/client/main.lua`
- Delete: `resources/[custom]/palm6_threads/client/debug.lua`

**Interfaces:**
- Consumes: `palm6_clothing_designs` (read-only, `status='deployed'`, by `citizenid`); `qbx_core` (via bridge); `illenium-appearance` exports (`getPedAppearance`/`setPedAppearance`, `SetPedComponentVariation`); the `Config.Garments` `garment_id → {component_id, drawable band}` map.
- Produces: a player whose deliverable curated items are equippable via a `/threads` wardrobe and persist across spawn through illenium. Ships `Config.Enabled = false` (inert).

- [ ] **Step 1: Update `config.lua` + `fxmanifest.lua`**

`config.lua`: keep `Config.Enabled = false`; add `Config.Garments = { [garmentId] = { component = 11, drawableBase = <reserved band start> }, ... }` mirroring the seeded catalog + the reserved index band; add `Config.MaxEquipped`. `fxmanifest.lua`: add `server_script 'server/main.lua'`, `shared_script 'shared/config.lua'`, `client_scripts { 'bridge/cl_game.lua', 'client/main.lua' }`, `server_scripts { 'bridge/sv_framework.lua', 'server/main.lua' }`, and `dependency 'oxmysql'`. Keep the loose-`stream/` note.

- [ ] **Step 2: Write `bridge/sv_framework.lua` (framework isolation)**

Mirror `palm6_business/bridge/sv_framework.lua`: `Bridge.GetCitizenId(src)` via `exports.qbx_core:GetPlayer`, `Bridge.Notify`, presence helpers. This is the ONLY server file touching `qbx_core`.

- [ ] **Step 3: Write `server/main.lua` (read-only deliverable fetch)**

On a client request (a DoS-budgeted, `CancelEvent()`-clean net event registered in `palm6_eventguard`), resolve the caller's `citizenid` via the bridge (NEVER client-asserted), read `palm6_clothing_designs WHERE citizenid = ? AND status = 'deployed'`, and return `{ designId, garmentId, component_id, drawable_index, texture_index }[]`. Read-only — the resource never writes clothing tables. Guard `Config.Enabled` (no-op + return empty when dark).

- [ ] **Step 4: Write `bridge/cl_game.lua` (illenium adapter)**

`Game.GetAppearance(ped)` / `Game.SetAppearance(ped, ap)` wrapping `exports['illenium-appearance']:getPedAppearance`/`setPedAppearance` (pcall-guarded, per the `palm6_fc_combat` precedent); `Game.ApplyComponent(ped, component, drawable, texture)` wrapping `SetPedComponentVariation(ped, component, drawable, texture, 2)`.

- [ ] **Step 5: Write `client/main.lua` (equip + `/threads` wardrobe)**

Request the caller's deliverable designs; the `/threads` wardrobe lists owned items and, on equip, (a) applies the component live via `Game.ApplyComponent`, and (b) reads the illenium appearance, writes the `{component, drawable, texture}` into the saved skin, and `setPedAppearance` so it re-applies on every spawn (persistence per spec §10). Unequip restores the base component. Everything inert while `Config.Enabled = false`. **The resource applies indices from the design row only** — it does not know or care whether the `.ytd` arrived via Stage A replacement or a Stage B addon (the delivery abstraction).

- [ ] **Step 6: Delete the Stage A spike command**

Remove `client/debug.lua` (the `threads_spike` local visual-check command is superseded by the real equip path).

- [ ] **Step 7: luaparse-clean all Lua**

```powershell
Push-Location 'C:\Users\Mgtda\Projects\Active\gtarp-threads\resources\[custom]\palm6_threads'
npx --yes luaparse fxmanifest.lua shared/config.lua bridge/sv_framework.lua server/main.lua bridge/cl_game.lua client/main.lua 2>&1
Pop-Location
```
Expected: no parse errors. (If `npx` hangs, read-verify each file for balanced blocks + `CancelEvent()`-before-yield in every net handler.)

- [ ] **Step 8: Commit**

```powershell
Push-Location 'C:\Users\Mgtda\Projects\Active\gtarp-threads'
git add "resources/[custom]/palm6_threads/fxmanifest.lua" "resources/[custom]/palm6_threads/shared/config.lua" "resources/[custom]/palm6_threads/bridge" "resources/[custom]/palm6_threads/server" "resources/[custom]/palm6_threads/client"
git rm "resources/[custom]/palm6_threads/client/debug.lua"
git commit -m @'
feat(threads): palm6_threads read+equip deliverable designs via illenium (Phase 1 Task 8)

Server reads palm6_clothing_designs by citizenid (status=deployed, read-only, bridge-
resolved identity). Client /threads wardrobe applies + persists {component,drawable,
texture} through illenium. Abstracts over Stage A/B asset delivery. Config.Enabled=false.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
'@
Pop-Location
```

---

### Task 9: End-to-end dry-run + IN-GAME GATE (David) — then flip

**Files:** none (deploy + manual verification; then a one-line flip commit)

**Interfaces:**
- Produces: the go/no-go to flip `Config.Enabled` — the only thing standing between Phase 1 and player-facing.

- [ ] **Step 1: DB migration lands (coordinated)**

Deploy so `palm6_dbmigrate` applies `0074` on boot; confirm the five `palm6_clothing_*` tables exist (`SHOW TABLES LIKE 'palm6_clothing_%'`). Coordinate with the shared-DB migration discipline (~60 worktrees).

- [ ] **Step 2: Web loop dry-run (flag ON in a non-prod/gated context)**

With the web routes enabled for staff only: grant a test citizen a perk slot (`syncPerkGrants`), design a curated item at `/dashboard/threads`, approve it at `/admin/threads` (confirm a stable `drawable_index` is allocated in `slots_alloc` and the design is `status='deployed'`).

- [ ] **Step 3: Seed the physical asset for the deliverable (Stage A bridge)**

Because the Stage B generator is out of scope, place the Phase-0-proven Stage A `.ytd` (+ base `.ydd`) for the test garment at the allocated reserved index in `palm6_threads/stream/`, so the `deployed` design has a real asset to render. This is the manual stand-in for the future worker; record it in `tools/threads-pipeline/README.md`.

- [ ] **Step 4: 🔴 MANUAL IN-GAME GATE (David)**

Temporarily set `Config.Enabled = true`, deploy, and in-game as the test citizen: open `/threads`, equip the approved item. **Verify:** (1) it shows the curated texture (not pink/missing); (2) it persists across respawn (illenium re-applies); (3) no script error / console spam; (4) `palm6_threads` is LOADED in `info.json`. Record PASS/FAIL in the README.
  - **PASS** → Phase 1 loop is proven end-to-end. Keep enabled if David greenlights player-facing, else re-disable.
  - **FAIL** → diagnose (equip path vs. asset vs. index mismatch) before any flip. Do NOT leave enabled on a failure.

- [ ] **Step 5: Commit the final gate state**

Set `Config.Enabled` to David's chosen state (default: back to `false` until the player-facing flip is greenlit) and commit.

```powershell
Push-Location 'C:\Users\Mgtda\Projects\Active\gtarp-threads'
git add "resources/[custom]/palm6_threads/shared/config.lua" "tools/threads-pipeline/README.md"
git commit -m @'
chore(threads): record Phase 1 in-game gate outcome + set final Config.Enabled (Task 9)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
'@
Pop-Location
```

---

## Phase 1 exit criteria

- [ ] `0074 palm6_clothing_*` tables applied idempotently on the shared game DB (Task 2).
- [ ] Perk/role slot grant is idempotent; consume/refund + in-flight cap enforced; unit tests green (Task 4).
- [ ] Curated design lifecycle enforced; approval allocates a **stable, never-reused** drawable index; unit tests green (Task 5).
- [ ] `/dashboard/threads` (curated only) + `/admin/threads` ship dark-by-default and gated (Tasks 6–7).
- [ ] `palm6_threads` reads deliverable designs by `citizenid` and equips+persists via illenium; ships `Config.Enabled = false` (Task 8).
- [ ] The end-to-end loop renders + persists in-game under David's manual gate; the flip is a deliberate, separate act (Task 9).
- [ ] No Tebex, no uploads, no AI, no Stage B generator built — only their seams.

## Self-review

**Spec coverage:** Phase 1 subsystems (1) entitlement ledger → Tasks 2,4; (2) curated editor → Tasks 3,6; (3) admin queue → Task 7; (4) FiveM equip path → Task 8. Data model spec §6 → Task 2 (all five tables). Entitlement §7 (perk grantor; Tebex stubbed) → Task 4. Editor §8 (curated only, 2D UV preview) → Task 6. Moderation §9 (curated skips heavy mod; text slur lint) → Tasks 3,5. Resource §10 (illenium persistence, `/threads` wardrobe, inert) → Task 8. Admin §11 → Task 7. Index stability §5.4 → Task 5 allocator + Task 2 `slots_alloc` PK. Explicitly deferred with clean seams: Tebex webhook §7/Phase 2 (`grantTebexSlot` stub, `slots.source='tebex'`), uploads/AI §8/Phases 3–4 (not built), Stage B binary generator + GH Actions worker §5/§12 (out of scope — `jobs` table + `approved→deliverable` seam only).

**Placeholder scan:** No vague "add error handling" steps. Every palm6-web internal is expressed as an intended interface signature + **[VERIFY AT EXECUTION]** and gated behind the Task 1 recon (allowed by convention). FiveM paths are concrete (verified against the in-tree `palm6_business`/`palm6_fc_combat`/`palm6_dbmigrate` precedents). The only manual/non-automated steps are the David in-game gate (Task 9) and the Stage A asset seed (Task 9 Step 3) — both explicitly flagged, matching Phase 0's gate discipline.

**Type consistency:** `citizenid` is `VARCHAR(64)` (DB) / `string` (web) / bridge-resolved (Lua) throughout — never client-asserted. `drawable_index`/`texture_index` are `INT` in DB and flow unchanged into `SetPedComponentVariation`. `Garment.componentId` (web) == `component_id` (DB) == `Config.Garments[].component` (Lua). Design `status` enum is identical across `db.ts`, `designs.ts`, and the game resource's `status='deployed'` read. `slots_alloc` PK `(component_id, drawable_index)` is the single enforcement point for the never-reused-index invariant, consumed by `approveDesign`'s allocator.

**Open questions for a human (O#):**
- **O1 — curated auto-approve vs. light staff gate.** Spec §9 says curated "skip heavy moderation" but §11 implies a staff gate; §14 Phase 1 lists "admin approve." This plan defaults `submitDesign` to a **light staff gate** (design lands in `/admin/threads`). If David wants curated to auto-approve+auto-allocate with no human click, Task 5 `submitDesign` collapses `submitted→approved→deployed` and Task 7's queue becomes an audit-only view. Decide before Task 5.
- **O2 — reserved index band size + first index.** Task 2 `slots_alloc` and Task 8 `Config.Garments[].drawableBase` need a concrete reserved band per component (spec §5.4 mandates a fixed band, gives no numbers). Must be chosen to not collide with base-game or existing addon drawables — confirm against the same base-game slot the Phase 0 Stage A spike used (`component 11`, jbib). Decide before Tasks 2 + 8.
- **O3 — `approved → deployed` in Phase 1.** With the Stage B generator out of scope, Phase 1 marks a design `deployed` on staff approval (Task 7) and seeds the asset manually (Task 9 Step 3). Confirm this staff-driven seam is acceptable as the Phase 1 stand-in, versus holding designs at `approved` until the Phase 2/Stage B worker exists (which would make the Task 8 equip path untestable until then).
