-- Local client debug command for the Stage A spike: wear the generated garment so we
-- can eyeball whether our CodeWalker-built .ytd renders on the ped. Visual check only,
-- no persistence, no net event. Gated behind Config.Enabled and removed before Phase 1.
-- (Real per-character delivery goes through illenium-appearance persistence in Phase 1.)

RegisterCommand('threads_spike', function()
    if not Config.Enabled then
        print('[palm6_threads] disabled (Config.Enabled=false)')
        return
    end
    local ped = PlayerPedId()
    local s = Config.Spike
    SetPedComponentVariation(ped, s.component, s.drawable, s.texture, 2)
    print(('[palm6_threads] applied comp=%d draw=%d tex=%d'):format(s.component, s.drawable, s.texture))
end, false)

-- Clean up nothing on stop (no state held); resource is inert until Enabled.
