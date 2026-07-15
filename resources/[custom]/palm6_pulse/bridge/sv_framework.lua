-- ============================================================================
-- palm6_pulse/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file that calls qbx_core / natives.
-- server/main.lua calls Bridge.* only, so porting to GTA VI = rewrite this file.
-- ============================================================================

Bridge = {}

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

function Bridge.GetPlayerName(src)
    local p = getPlayer(src)
    if p and p.PlayerData and p.PlayerData.charinfo then
        local ci = p.PlayerData.charinfo
        return ('%s %s'):format(ci.firstname or '', ci.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    end
    return GetPlayerName(src) or ('player %d'):format(src)
end

-- ox_lib toast to one player. Console (src 0) has no ped → no-op.
function Bridge.Notify(src, title, msg, t)
    if src == 0 then return end
    TriggerClientEvent('ox_lib:notify', src, { title = title, description = msg, type = t or 'inform' })
end

-- Server-wide toast (window open). Server-emitted (source 0 on the client-facing
-- event), display-only, holds no authority.
function Bridge.Broadcast(title, msg, t)
    TriggerClientEvent('ox_lib:notify', -1, { title = title, description = msg, type = t or 'inform', duration = 9000 })
end

-- Reply to a command invoker via the branded palm6_ui panel (or console prints).
function Bridge.Reply(src, lines)
    if src == 0 then
        for _, line in ipairs(lines) do print('[palm6_pulse] ' .. line) end
        return
    end
    TriggerClientEvent('palm6_ui:show', src, { tag = 'PULSE', color = { 255, 90, 120 }, lines = lines })
end

function Bridge.ResourceStarted(name)
    return GetResourceState(name) == 'started'
end

function Bridge.RegisterCommand(name, handler)
    RegisterCommand(name, handler, false)
end

function Bridge.GetConvar(name)
    local v = GetConvar(name, '')
    return v ~= '' and v or nil
end

function Bridge.GetOnlineCount()
    return #GetPlayers()
end

-- Map every online player to a citizenid (nils skipped) — used for the
-- population-aware "how many distinct gangs are online" style checks.
function Bridge.GetOnlineCitizenIds()
    local out = {}
    for _, sid in ipairs(GetPlayers()) do
        local cid = Bridge.GetCitizenId(tonumber(sid))
        if cid then out[#out + 1] = cid end
    end
    return out
end

-- Credit clean cash (only used for the optional, hard-capped check-in tip).
function Bridge.AddCash(src, amount, reason)
    local p = getPlayer(src)
    if not p or not p.Functions then return false end
    p.Functions.AddMoney('cash', amount, reason)
    return true
end

-- Best-effort Discord webhook post (self-contained; never throws to caller).
function Bridge.PostDiscord(webhook, embed)
    if not webhook then return end
    pcall(function()
        PerformHttpRequest(webhook, function() end, 'POST',
            json.encode({ embeds = { embed } }), { ['Content-Type'] = 'application/json' })
    end)
end
