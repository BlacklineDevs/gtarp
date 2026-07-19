# palm6_fc — Def Jam Fight Club (Phase 0) rollout & cutover

`palm6_fc_core` owns the single prod gate: `Config.Enabled` (in `config.lua`,
ships **`false`** = prod-inert). Every fc resource reads it via
`exports.palm6_fc_core:Config().Enabled` before opening a match / running
combat / playing arena audio.

## Config.Enabled semantics (§15)

- **`Enabled = false`** (default, prod-inert):
  - **No new matches open** — challenge-at-the-ring, `/fcbet`, and OpenMatch all
    refuse; arena crowd/audio poll loops stay idle.
  - **Betting is frozen** — `/fcbet` is refused entirely while disabled.
  - **Settlement still reconciles** — the boot reconcile still re-drives any
    interrupted payout idempotently (`status='resolved' AND settled=0` for
    fightclub; `rep_awarded=0 AND is_pve=0` for progression). Money already in
    flight is never stranded by shipping dark.
- **`Enabled = true`** (after David's prod feel-test): combat's
  challenge + SELECT + OpenMatch + GoLive + countdown are live. These ship
  **WITH** the `palm6_fightclub` money rewire (not after it), so prod is never
  left half-wired/inert.
- **Mid-match flip to `false`** (emergency kill): `palm6_fc_combat`'s
  `onResourceStop`/boot path fires the `palm6_fc_combat:teardown` no-contest
  broadcast to `-1` (every client stuck mid-fight is freed — no one left
  invincible/frozen) AND `LiveVoidMatch` flips the open `live` row to
  `resolved, winner=NULL, method='void', settled=0` → `settleMatch` runs the
  draw path: **bets refunded, both entry stakes returned**. No stranded bet or
  ante.

## Load order (custom.cfg)

Canonical fc ensure block (money-safe dependency graph):

```
palm6_eventguard  ->  palm6_dbmigrate  ->  palm6_fc_core  ->  palm6_fightclub
  ->  palm6_fc_combat  ->  palm6_fc_hud  ->  palm6_fc_arena  ->  palm6_fc_progression
```

- `palm6_eventguard` registers its net-event guards FIRST (handler-chain order),
  including the drop-not-kick **combat-class** budget for
  `palm6_fc_combat:strike/connect/block/break`.
- `palm6_dbmigrate` creates/patches the fc tables BEFORE any fc resource reads
  them (all statements `IF NOT EXISTS`).
- Arena audio is a **client handler inside `palm6_fc_arena`**
  (`client/audio.lua`, native `PlaySoundFrontend` only — zero shipped assets),
  not a separate ensured resource.

## Debug driver

`/fcdebug open|live|resolve|void` (palm6_fightclub), `/fcfin` (palm6_fc_combat),
and `/fcarenatest` (palm6_fc_arena) are ace-gated on `palm6_fc.debug`
(`add_ace group.admin palm6_fc.debug allow` in custom.cfg; console src 0 always
allowed). Use them to drive betting → progression → HUD → audio **before** real
combat.

## Player-facing announcement

`/fcjoin` and `/fcleave` (the old queue) are **GONE** — replaced by
challenge-at-the-ring. Announce this so no one waits on a dead command.
