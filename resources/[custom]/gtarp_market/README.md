# gtarp_market — Palm6 Commodity Exchange

A server-authoritative **supply/demand market** for the legal economy's raw
goods. It gives `gtarp_grind`'s outputs a living price instead of a flat vendor
rate, and it is the **only buyer** for `animal_pelt` (which `gtarp_grind` mints
as a hunting drop but ships no buyer for).

## The loop

Gather raw goods with `gtarp_grind` (fish / ore / meat / pelts), then bring them
to the **Commodity Exchange** and press **E** to sell everything sellable at the
current live price. Check prices any time with **`/market`** (a branded panel).

- **`raw_fish`, `raw_ore`, `raw_meat`** can be sold at *either* their fixed
  `gtarp_grind` buyer (the safe floor, which also has the grind XP bonus) *or*
  here at the fluctuating exchange price — a genuine sell-now-or-time-it choice.
- **`animal_pelt`** can only be sold here.

## Price model (server-authoritative, wall-clock, no ticks)

Each commodity's price is a **pure function** of its last persisted
`{price, timestamp}` and the current time:

- **Recovery:** price climbs back toward its rested `base` at
  `RecoverPctPerMin` of base per minute (capped at base).
- **Impact:** every unit sold pushes the price down by `ImpactPct` of base,
  applied **marginally within a single sale** — dumping a big stack crashes the
  price as it sells, so there is no selling 500 units at the top.
- **Floor:** price never drops below `floorPct` of base.

Because price is recomputed from persisted state on every read, the market is
**restart- and relog-safe** with zero client ticks — the same discipline as the
grow / dry / cook timers in `gtarp_drugs`.

## Money safety

- Atomic per-player sell **cooldown set before any yield** (a same-tick double
  fire can't bypass it).
- **Server-side proximity** check — the client is never trusted that it's at the
  counter; it sends no items, amounts or prices.
- **Consume before grant** — items are removed before cash is paid, and the
  market price only moves on a real, completed sale (a failed `RemoveItem`
  neither pays nor moves the market).
- Trade ledger insert is **best-effort** and never blocks or undoes a sale.

## Files / wiring

- `sql/0046_market.sql` — `gtarp_market_state` (price state) + `gtarp_market_trades` (ledger).
- `gtarp_eventguard` budgets `gtarp_market:sell`.
- `gtarp_economy` shows an informational **clean-cash** line via the
  `GetSummary` export (`{ commodities, unitsSold, totalPaid }`).
- Exchange coords in `shared/config.lua` are a **Tier-3 placeholder — VERIFY
  IN-GAME** and reposition freely.

## Bridge pattern (GTA VI portability)

All framework/native access is isolated in `bridge/sv_framework.lua` (items,
cash, coords, panel reply) and `bridge/cl_game.lua` (blip, prompt, interact).
`server/main.lua` and `client/main.lua` call only `Bridge.*` / `Game.*`, so a
port rewrites the two bridge files. See `docs/GTA6-READINESS.md` §3.

## Deferred (v2)

- **Refining tier:** `raw_ore -> refined_metal`, `animal_pelt -> cured_leather`,
  etc. — a value-add sink and a reason to hold rather than dump. Needs new
  `ox_inventory` item defs (+ PNGs) and their own market curves.
- **Scarcity premium:** let a long-untouched commodity drift *above* base.
