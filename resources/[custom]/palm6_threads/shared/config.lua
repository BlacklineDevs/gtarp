Config = {}

-- Prod-inert until the Stage A spike is proven in-game, per PALM6 convention.
-- Flip to true ONLY for a controlled feel-test deploy, then revert.
Config.Enabled = false

-- The component + reserved drawable/texture index the spike garment lives at.
-- Fill these from the base-template's .ymt (which drawable index, and texture 0).
-- Common component ids: 11 = jacket/top (jbib), 8 = undershirt, 4 = legs, 6 = feet.
Config.Spike = { component = 11, drawable = 0, texture = 0 }
