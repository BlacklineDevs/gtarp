# palm6_pulse — live city director

The "why is this small server never dead at 8pm" layer. Instead of static timed
events that fire on a dumb clock (half of them to an empty city), palm6_pulse is
a **director**: every `TickSeconds` it reads how many players are online and what
they're doing, then opens the single best-fitting **Pulse Window** — a ~15-minute,
city-wide, transparent **payout modifier** — and announces it.

## Player loop
- Log in → `/pulse` shows the **City Pulse meter** (0–100), the active window +
  countdown, and your **convergence streak**.
- Converge on the live activity → `/pulse checkin` once per window banks **pulse
  points** and extends your streak (the daily-return hook). Points have **no cash
  value** — they feed the season scoreboard.

## Windows
| Kind | Domain | Effect (a multiplier consumers read) | Fires when |
|------|--------|--------------------------------------|-----------|
| Boomtown | `grind` | legal fish/mine/hunt sale value ↑ | low online / early |
| Hot Exchange | `market` | one commodity's price spikes | population gate |
| Bounty Surge | `bounty` | posted bounty payouts ↑ | population gate |
| Crackdown | `police` | arrest/citation rewards ↑ | more online |
| Turf War | `gang` | turf/rep gains ↑ | ≥2 gangs online |

## Money-safety
Pulse **never grants money/items** except the check-in reward, which is gated by
an atomic `UNIQUE(window_id, citizenid)` insert — spamming can't double-collect.
It only publishes a **capped scalar** (`Config.MaxModifier`). The paying resource
still does its own consume-before-grant, multiplying its already-authoritative
payout by a **server-read** modifier — a client can never assert a multiplier.

## Modifier bus — frozen export API (server-only, add-only)
```lua
exports.palm6_pulse:GetActiveModifier(domain[, target]) -- number, 1.0 if none (safe no-op), capped
exports.palm6_pulse:GetActive()   -- table|nil { kind,label,domain,modifier,target,endsAt,reason }
exports.palm6_pulse:GetMeter()    -- 0..100 city activity index
exports.palm6_pulse:GetSummary()  -- { activeKind, windowsToday, checkinsToday, meter }
```
Wired consumer (Phase 1): **palm6_market** multiplies `currentPrice(item)` by
`GetActiveModifier('market', item)` during a Hot Exchange window (one pcall'd
line; market runs standalone if pulse is absent). Bounty/citations/turf can adopt
the same one-liner to honor `bounty`/`police`/`gang` windows.

## Composition / soft deps
All sibling reads (`palm6_gangs:GetGang`, discord webhook, market) are pcall-
wrapped, so pulse boots and runs inert-safe if any are absent. Announces via a
server-wide toast + optional Discord webhook (`set palm6:discord_pulse_webhook`).
cityfeed narration is **gated off** (`Config.EmitCityfeed=false`) until the bot
adds a `pulse` event type (cross-repo).

## Not a duplicate of
flashdrop (physical item scramble), palm6_season (passive scoreboard), or
discord/cityfeed (announcers). Pulse is the reactive scheduler + modifier bus
those don't provide.

## Migration
`sql/0048_pulse.sql` (3 tables). Also embedded in `palm6_dbmigrate` so prod
applies it at boot (CI never touches the DB).

## TODO(David) — tune in `shared/config.lua`
`MinOnline` (default 4), reward amounts (`PointsPerCheckin`, `CashTip` default 0),
cadence (`TickSeconds`/`WindowSeconds`/`CooldownSeconds`), window weights, and the
`MarketCommodities` list (keep in sync with palm6_market). In-game feel-test the
window cadence + the `/pulse` panel.
