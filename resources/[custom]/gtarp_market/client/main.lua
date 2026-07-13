-- ============================================================================
-- gtarp_market/client/main.lua
--
-- Pure logic: the exchange blip and the proximity "press E to sell" prompt.
-- All natives / ox_lib UI go through Game.* (bridge/cl_game.lua). To port to
-- GTA VI, rewrite the bridge, not this file. See docs/GTA6-READINESS.
--
-- One E-press at the counter fires gtarp_market:sell; the SERVER decides what
-- the player holds, prices it live, and pays — the client sends no amounts,
-- items or prices (nothing here is trusted). /market (the price board) is a
-- server command, so it needs no client code.
-- ============================================================================

CreateThread(function()
    local e = Config.Exchange
    Game.CreateBlip(e.coords, e.blip.sprite, e.blip.colour, e.blip.scale, e.label)
end)

CreateThread(function()
    local e = Config.Exchange
    while true do
        local wait = 800
        local me = Game.GetPlayerCoords()
        if Game.DistanceBetween(me, e.coords) <= Config.InteractRadius then
            wait = 0
            Game.ShowHelpThisFrame('Press ~INPUT_PICKUP~ to sell raw goods at the ' .. e.label)
            if Game.InteractPressed() then
                TriggerServerEvent('gtarp_market:sell')
            end
        end
        Wait(wait)
    end
end)
