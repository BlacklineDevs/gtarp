-- ============================================================================
-- palm6_fc_arena/client/audio.lua
--
-- Minimum Def Jam arena audio (spec §12): crowd bed, per-hit SFX, a Blazin
-- ready cue, a finisher stinger, a KO crowd roar, a countdown beep. Native
-- PlaySoundFrontend ONLY -> zero shipped assets, provenance-clean (GTA's own
-- frontend sound sets). No authority, no money, no net events produced.
--
-- Folded into palm6_fc_arena (the presentation layer) rather than a separate
-- ensured resource, so custom.cfg keeps the canonical 8-resource fc block.
-- Client-only, presentation-only: reads exports.palm6_fc_core:Config()/
-- StateKeys() and reacts to the palm6_fc_combat server->client broadcasts + the
-- fc match statebag. Module-locals are named CoreCfg/CoreKeys so they never
-- shadow this resource's own `Config` global (shared/config.lua).
--
-- The sound set/name pairs below are PLACEHOLDERS. PlaySoundFrontend silently
-- no-ops on an unknown name/set (it never raises a Lua error), so a wrong pick
-- is a missing sound, never a SCRIPT ERROR -- boot-safe regardless. David swaps
-- and tunes the exact sets in the in-game feel-test (§14).
-- ============================================================================

local CoreCfg  = nil
local CoreKeys = nil

local function cfg()
    if CoreCfg == nil then
        local ok, c = pcall(function() return exports.palm6_fc_core:Config() end)
        if ok then CoreCfg = c end
    end
    return CoreCfg
end

local function keys()
    if CoreKeys == nil then
        local ok, k = pcall(function() return exports.palm6_fc_core:StateKeys() end)
        if ok then CoreKeys = k end
    end
    return CoreKeys
end

local function play(name, set)
    PlaySoundFrontend(-1, name, set, true)
end

-- Per-hit swing/impact SFX: the server told this client to play a strike clip
-- (palm6_fc_combat:playClip, §6 move clock; broadcast to the fighters).
RegisterNetEvent('palm6_fc_combat:playClip', function(data)
    if not data or not data.moveId then return end
    play('MELEE_Fist_Takedown', 'CELEBRATION_SOUNDSET')  -- placeholder swing/impact
end)

-- Finisher stinger: the Blazin cinematic starts (palm6_fc_combat:finisher, §7).
RegisterNetEvent('palm6_fc_combat:finisher', function(data)
    if not data then return end
    play('Bed', 'DLC_LOWRIDER_RELAY_RACE_SOUNDS')  -- placeholder stinger bed
end)

-- KO crowd roar: the victim is dropped (palm6_fc_combat:koRagdoll, §6 KO).
RegisterNetEvent('palm6_fc_combat:koRagdoll', function(data)
    play('CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET')  -- placeholder crowd roar
end)

-- Countdown beep: 3-2-1 into LIVE (palm6_fc_combat:countdown, §5 COUNTDOWN).
RegisterNetEvent('palm6_fc_combat:countdown', function(data)
    play('Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS')  -- placeholder beep
end)

-- Crowd bed + Blazin ready cue. Runs only while the LOCAL player is IN a LIVE
-- fc match (LocalPlayer.state['fc:active']); reads the throttled match statebag
-- (fc_core StateKeys shape, written by palm6_fc_combat §6/§7). PlaySoundFrontend
-- is one-shot, so the "bed" is a low-cadence re-trigger, not a true loop. Gated
-- on Config.Enabled so it is fully inert when the feature ships dark (§15).
CreateThread(function()
    local lastBed = 0
    local blazinFired = false
    while true do
        local wait = 1000
        local c = cfg()
        local k = keys()
        if c and c.Enabled and k then
            local matchId = LocalPlayer.state[k.PLAYER_ACTIVE]
            local slot    = LocalPlayer.state[k.PLAYER_SLOT]
            if matchId and matchId ~= false then
                local st = GlobalState[k.matchKey(matchId)]
                if st and st.status == 'live' and st.roundStarted then
                    local t = GetGameTimer()
                    if t - lastBed > 4000 then
                        play('Crowd_Cheer', 'HUD_MINI_GAME_SOUNDSET')  -- placeholder crowd bed
                        lastBed = t
                    end
                    -- Blazin ready cue: edge-trigger ONCE when this fighter's
                    -- momentum fills to FullThreshold (§7 telegraph). Re-arms
                    -- when it drops back below (e.g. after a finisher fires).
                    local me = slot and st.slot and st.slot[slot]
                    if me and me.blazin and c.Blazin and me.blazin >= c.Blazin.FullThreshold then
                        if not blazinFired then
                            play('Rank_Up', 'HUD_AWARDS')  -- placeholder Blazin cue
                            blazinFired = true
                        end
                    else
                        blazinFired = false
                    end
                    wait = 250
                else
                    blazinFired = false
                end
            end
        end
        Wait(wait)
    end
end)
