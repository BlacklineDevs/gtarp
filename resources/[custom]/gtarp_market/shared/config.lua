-- ============================================================================
-- gtarp_market/shared/config.lua
--
-- The Palm6 Commodity Exchange: a server-authoritative, supply/demand market
-- for the LEGAL economy's raw goods (gtarp_grind outputs). Prices move —
-- every unit sold pushes a commodity's price down, and it recovers toward its
-- rested `base` over wall-clock time. The exchange is also the ONLY buyer for
-- animal_pelt (gtarp_grind mints it as a hunting drop but ships no buyer).
--
-- The DESIGN (commodities, price model, tuning) is Tier 1 and carries to
-- GTA VI. The coords (exchange location) are Tier 3 — Los Santos map data,
-- VERIFY IN-GAME and reposition freely.
-- ============================================================================

Config = {}

Config.Debug = false

-- The exchange location. Tier-3 placeholder near the LS port/warehouse
-- district — VERIFY IN-GAME and move to taste.
Config.Exchange = {
    label  = 'Palm6 Commodity Exchange',
    coords = vector3(-40.00, -2530.00, 6.00),
    blip   = { sprite = 52, colour = 2, scale = 0.9 },
}

-- Interaction radius (metres) for the exchange counter. Matches gtarp_grind.
Config.InteractRadius = 2.5

-- Seconds between sells per player (server-enforced, atomic).
Config.SellCooldown = 3

-- ---------------------------------------------------------------------------
-- Price model (server-authoritative, wall-clock, computed lazily on read):
--   * price recovers toward `base` at RecoverPctPerMin of base per minute
--     (capped at base — base is the rested ceiling)
--   * each unit sold pushes that commodity's price down by ImpactPct of base,
--     applied MARGINALLY within a single sale so dumping a big stack crashes
--     the price mid-sale (no selling 500 units at the top price)
--   * price is floored at floorPct of base
-- Nothing is a client tick and nothing is stored per-frame: price is a pure
-- function of {last persisted price, last persisted timestamp, now}, so it is
-- restart- and relog-safe exactly like the grow/dry/cook timers in gtarp_drugs.
-- ---------------------------------------------------------------------------
Config.ImpactPct        = 0.02   -- -2% of base per unit sold (marginal)
Config.RecoverPctPerMin = 2.5    -- +2.5% of base per minute, back toward base

-- Safety ceiling on how many units one sale will price-walk (anti-DoS on the
-- marginal loop; real stacks on a 48-slot server are far below this).
Config.MaxUnitsPerSale = 2000

-- Commodities the exchange buys. `base` is the rested price; `grindFloor` is
-- gtarp_grind's fixed buyer price, shown on /market for comparison (nil means
-- the exchange is the only buyer — animal_pelt).
Config.Commodities = {
    { item = 'raw_fish',    label = 'Raw Fish',    base = 60, floorPct = 0.40, grindFloor = 45 },
    { item = 'raw_ore',     label = 'Raw Ore',     base = 95, floorPct = 0.40, grindFloor = 70 },
    { item = 'raw_meat',    label = 'Raw Meat',    base = 72, floorPct = 0.40, grindFloor = 55 },
    { item = 'animal_pelt', label = 'Animal Pelt', base = 90, floorPct = 0.45, grindFloor = nil },
}

-- gtarp_ui panel styling for the /market price board (money green).
Config.Panel = { tag = 'MARKET', color = { 88, 196, 122 } }

-- The public command that prints the live price board.
Config.Command = 'market'
