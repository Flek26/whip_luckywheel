-- ============================================
-- whip_luckywheel — client: the wheel, the podium car, spinning it
-- ============================================
--
-- The map's stand stays. GTA's wheel (the part that turns) is made here and set on it, and every game near turns
-- it the same way when told to: from where it is, to the segment the server drew, over spinMs. Using the wheel is
-- GTA's own moves at the stand: step up, raise an arm, pull, watch, celebrate.

local K = Config.Keys
local SEG = #Config.Segments
local STEP = 360.0 / SEG
local DICT_M = 'anim_casino_a@amb@casino@games@lucky7wheel@male'
local DICT_F = 'anim_casino_a@amb@casino@games@lucky7wheel@female'

Live = nil    -- { base, ownedBase, wheel, heading, angle, busy, podium, podiumMap, car, spinToken }
local Using = nil   -- { phase = 'ready' | 'spinning', dict, origin, heading, how, stand }

local function notify(msg, kind) exports.whip_core:Notify(msg, kind or 'inform') end
local function loadModel(name) return exports.whip_core:LoadModel(name) end
local function gone(ent) if ent and DoesEntityExist(ent) then DeleteEntity(ent) end end

-- ============================================
-- The wheel
-- ============================================

local function wheelPos(L) return GetOffsetFromEntityInWorldCoords(L.base, Config.Wheel.wheelOffset.x, Config.Wheel.wheelOffset.y, Config.Wheel.wheelOffset.z) end

local function setAngle(L, a, turn)
    if not (L and DoesEntityExist(L.wheel)) then return end
    SetEntityRotation(L.wheel, 0.0, a + (turn or Config.Wheel.turn), L.heading, 2, true)
end

local function intoRoom(L, ent)
    if L.interior ~= 0 then ForceRoomForEntity(ent, L.interior, L.room) end
end

local soundsReady = false
local function sound(name, ent)
    local S = Config.Sounds
    if not S.bank or not name then return end
    if not soundsReady then soundsReady = RequestScriptAudioBank(S.bank, false, -1) end
    PlaySoundFromEntity(-1, name, ent, S.set, false, 0)
end

local function ease(f) return 1.0 - (1.0 - f) ^ 3 end

--- Turns the wheel from d.from to d.to: d.pull ms still (the arm coming down), then d.ms slowing to a stop.
--- elapsed: how far into it we already are (joined mid-spin).
local function runSpin(L, d, elapsed, turn)
    L.spinToken = (L.spinToken or 0) + 1
    local mine = L.spinToken
    CreateThread(function()
        local t0 = GetGameTimer() - (elapsed or 0)
        local lastSeg
        while Live == L and L.spinToken == mine do
            local t = GetGameTimer() - t0 - d.pull
            if t >= d.ms then break end
            if t > 0 then
                local a = d.from + (d.to - d.from) * ease(t / d.ms)
                setAngle(L, a, turn)
                local seg = math.floor((-a + STEP / 2) / STEP)
                if lastSeg and seg ~= lastSeg then sound(Config.Sounds.tick, L.wheel) end
                lastSeg = seg
            end
            Wait(0)
        end
        if Live == L and L.spinToken == mine then
            L.angle = d.to % 360.0
            setAngle(L, L.angle, turn)
        end
    end)
end

-- ============================================
-- The podium
-- ============================================

local function makePodium(L, car)
    local P = Config.Podium
    if not P.enabled or type(car) ~= 'table' or not car.model then return end
    local at = P.coords
    local heading = 0.0
    local map = GetClosestObjectOfType(at.x, at.y, at.z, 2.0, joaat(P.model), false, false, false)
    if map ~= 0 then
        at, heading = GetEntityCoords(map), GetEntityHeading(map)
        if P.spin then
            -- The map's podium can't turn: ours goes in its place.
            local h = loadModel(P.model)
            if h then
                local obj = CreateObjectNoOffset(h, at.x, at.y, at.z, false, false, false)
                SetModelAsNoLongerNeeded(h)
                SetEntityRotation(obj, 0.0, 0.0, heading, 2, true)
                FreezeEntityPosition(obj, true)
                local interior = GetInteriorFromEntity(map)
                if interior ~= 0 then ForceRoomForEntity(obj, interior, GetRoomKeyFromEntity(map)) end
                SetEntityVisible(map, false, false)
                L.podium, L.podiumMap = obj, map
            end
        end
    end
    local vh = loadModel(car.model)
    if not vh then return print(('[whip_luckywheel] the podium car %s could not be loaded'):format(car.model)) end
    local v = CreateVehicle(vh, at.x, at.y, at.z + P.carUp, heading, false, false)
    SetModelAsNoLongerNeeded(vh)
    if v == 0 then return end
    SetEntityAsMissionEntity(v, true, true)
    FreezeEntityPosition(v, true)
    SetEntityInvincible(v, true)
    SetVehicleDoorsLocked(v, 2)
    SetVehicleDirtLevel(v, 0.0)
    SetVehicleNumberPlateText(v, 'LUCKY')
    if car.colours then SetVehicleColours(v, car.colours[1] or 0, car.colours[2] or 0) end
    if L.interior ~= 0 then ForceRoomForEntity(v, L.interior, L.room) end
    L.car, L.carAt, L.carHeading = v, at, heading
end

CreateThread(function()
    while true do
        local L = Live
        if L and Config.Podium.spin and (L.car or L.podium) then
            local h = ((L.carHeading or 0.0) + GetGameTimer() / 1000.0 * Config.Podium.perSec) % 360.0
            if L.podium then SetEntityHeading(L.podium, h) end
            if L.car and DoesEntityExist(L.car) then SetEntityHeading(L.car, h) end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ============================================
-- Using it
-- ============================================

local function has(dict, anim) return anim and GetAnimDuration(dict, anim) > 0.0 end
local function first(dict, list)
    for _, a in ipairs(list) do if has(dict, a) then return a end end
end

local function scene(U, anim, loop)
    local o = U.origin
    local s = NetworkCreateSynchronisedScene(o.x, o.y, o.z, 0.0, 0.0, U.heading, 2, not loop, loop, 1.0, 0.0, 1.0)
    NetworkAddPedToSynchronisedScene(PlayerPedId(), s, U.dict, anim, 2.0, -2.0, 13, 16, 1000.0, 0)
    NetworkStartSynchronisedScene(s)
    return s
end

--- Plays one through (if the game has it), and waits for it. false if it was skipped.
local function playOnce(U, anim, cut)
    if not has(U.dict, anim) then return false end
    scene(U, anim, false)
    Wait(math.max(300, math.floor(GetAnimDuration(U.dict, anim) * 1000) - (cut or 100)))
    return true
end

local function lookAt(pos, at, fov)
    local d = at - pos
    local pitch = math.deg(math.atan(d.z, math.sqrt(d.x * d.x + d.y * d.y)))
    exports.whip_core:PlayCamera({
        pos = pos, rot = vector3(pitch, 0.0, GetHeadingFromVector_2d(d.x, d.y)), fov = fov,
        exitKey = false, async = true, transitionIn = 600, transitionOut = 600,
    })
end

local function wheelCamera(L)
    local C = Config.Camera
    if not C.enabled then return end
    local o = Config.Wheel.wheelOffset
    local pos = GetOffsetFromEntityInWorldCoords(L.base, o.x, o.y - C.back, o.z + C.up)
    lookAt(pos, wheelPos(L), C.fov)
    Using.camera = true
end

local function key(k) return exports.whip_core:KeyHint(k.text, k.button) end

local function finish(U, tell)
    if Using ~= U then return end
    if tell then TriggerServerEvent('whip_luckywheel:leave') end
    exports.whip_core:HideText()
    if U.camera then exports.whip_core:StopCamera() end
    if not IsEntityDead(PlayerPedId()) and U.dict then
        if not playOnce(U, 'exit_to_standing', 250) then ClearPedTasks(PlayerPedId()) end
    end
    ClearPedTasks(PlayerPedId())
    exports.whip_core:UnblockControls('whip_luckywheel')
    Using = nil
end

local function celebrate(U, how)
    local list = ({
        huge = { 'win_huge', 'win_big', 'win' },
        big  = { 'win_big', 'win', 'win_exit' },
        win  = { 'win', 'win_exit' },
    })[how]
    local anim = list and first(U.dict, list)
    if anim then
        playOnce(U, anim, 150)
        if anim:find('exit') then U.dict = nil end   -- already walked off: no exit after it
    end
    if U.camera then exports.whip_core:StopCamera() U.camera = false end
    if how ~= 'lose' then sound(Config.Sounds.win, Live and Live.wheel or PlayerPedId()) end
end

local function stepUp(L)
    if Using then return end
    local res, why = exports.whip_core:Callback('whip_luckywheel:use')
    if not res then return notify(why or 'Not now', 'error') end

    local ped = PlayerPedId()
    local dict = GetEntityModel(ped) == `mp_f_freemode_01` and DICT_F or DICT_M
    if not exports.whip_core:LoadAnimDict(dict) then
        dict = DICT_M
        if not exports.whip_core:LoadAnimDict(dict) then
            TriggerServerEvent('whip_luckywheel:leave')
            return notify('The wheel\'s moves could not be loaded', 'error')
        end
    end
    local so = Config.Wheel.standOffset
    local U = {
        phase = 'ready', dict = dict,
        origin = GetOffsetFromEntityInWorldCoords(L.base, so.x, so.y, so.z),
        heading = (L.heading + Config.Wheel.standTurn) % 360.0,
    }
    Using = U
    exports.whip_core:BlockControls('whip_luckywheel', { all = true, except = { 1, 2, 199, 200, 245, 249 }, mode = true })

    -- Walk up to wherever the nearer way in starts.
    local enter, start, turn, best
    for _, a in ipairs({ 'enter_right_to_baseidle', 'enter_left_to_baseidle' }) do
        if has(dict, a) then
            local o = U.origin
            local p = GetAnimInitialOffsetPosition(dict, a, o.x, o.y, o.z, 0.0, 0.0, U.heading, 0.0, 2)
            local d = #(GetEntityCoords(ped) - p)
            if not best or d < best then
                enter, start, best = a, p, d
                turn = GetAnimInitialOffsetRotation(dict, a, o.x, o.y, o.z, 0.0, 0.0, U.heading, 0.0, 2).z
            end
        end
    end
    if start and best > 0.3 then
        TaskGoStraightToCoord(ped, start.x, start.y, start.z, 1.0, 4000, turn, 0.05)
        local t0, closest, still = GetGameTimer(), math.huge, 0
        while GetGameTimer() - t0 < 4000 and Using == U do
            Wait(100)
            local d = #(GetEntityCoords(ped).xy - start.xy)
            if d < 0.25 then break end
            if d < closest - 0.02 then closest, still = d, 0 else still = still + 1 end
            if still >= 5 then break end
        end
    end
    if Using ~= U then return end
    if enter then playOnce(U, enter, 150) end
    if Using ~= U then return end
    playOnce(U, 'enter_to_armraisedidle', 150)
    if Using ~= U then return end
    if has(dict, 'armraisedidle') then scene(U, 'armraisedidle', true) end

    local cost = tonumber(res.cost) or 0
    local hint = key(K.spin) .. ' / LMB Spin the wheel' .. (cost > 0 and (' (%s chips)'):format(cost) or '')
        .. '  |  ' .. key(K.leave) .. ' Step away'
    exports.whip_core:ShowText(hint, { icon = 'dollar' })

    -- Waiting for the spin.
    while Using == U and U.phase == 'ready' do
        if U.stand then
            if U.stand ~= 'away' then notify(U.stand, 'error') end
            return finish(U, false)
        end
        local spinNow = exports.whip_core:IsKeyPressed(K.spin.key, K.spin.pad) or IsDisabledControlJustPressed(0, 24)
        if spinNow then
            exports.whip_core:HideText()
            local ok, err = exports.whip_core:Callback('whip_luckywheel:spin')
            if not ok then
                notify(err or 'The wheel won\'t turn', 'error')
                return finish(U, false)
            end
            U.phase = 'spinning'
        elseif exports.whip_core:IsKeyPressed(K.leave.key, K.leave.pad) then
            return finish(U, true)
        end
        Wait(0)
    end
    if Using ~= U then return end

    -- The pull, then watching it go round.
    local pull = first(dict, { 'armraisedidle_to_spinningidle_high', 'armraisedidle_to_spinningidle_med', 'armraisedidle_to_spinningidle_low' })
    if pull then
        scene(U, pull, false)
        Wait(Config.Timing.pullMs)
        if Live then wheelCamera(Live) end
        Wait(math.max(0, math.floor(GetAnimDuration(dict, pull) * 1000) - Config.Timing.pullMs - 100))
    elseif Live then
        wheelCamera(Live)
    end
    local idle = first(dict, { 'spinningidle_high', 'spinningidle_med', 'spinningidle_low' })
    if idle then scene(U, idle, true) end

    local t0 = GetGameTimer()
    while Using == U and not U.how and GetGameTimer() - t0 < Config.Timing.spinMs + 8000 do Wait(100) end
    if Using ~= U then return end
    celebrate(U, U.how or 'win')
    finish(U, false)
    if U.how == 'lose' and not IsEntityDead(PlayerPedId()) and exports.whip_core:LoadAnimDict('gestures@m@standing@casual') then
        TaskPlayAnim(PlayerPedId(), 'gestures@m@standing@casual', 'gesture_damn', 8.0, -8.0, -1, 48, 0.0, false, false, false)
    end
end

RegisterNetEvent('whip_luckywheel:won', function(how) if Using then Using.how = how end end)
RegisterNetEvent('whip_luckywheel:stand', function(reason) if Using then Using.stand = reason or 'away' end end)
AddEventHandler('whip_core:player:died', function()
    if Using then
        local U = Using
        exports.whip_core:HideText()
        if U.camera then exports.whip_core:StopCamera() end
        exports.whip_core:UnblockControls('whip_luckywheel')
        if U.phase == 'ready' then TriggerServerEvent('whip_luckywheel:leave') end
        Using = nil
    end
end)

-- ============================================
-- What the server says
-- ============================================

RegisterNetEvent('whip_luckywheel:fx', function(kind, d)
    local L = Live
    if not L or type(d) ~= 'table' then return end
    if kind == 'user' then
        L.busy = d.src
    elseif kind == 'spin' then
        L.busy = d.src
        runSpin(L, d, 0)
    elseif kind == 'stop' then
        if d.how ~= 'lose' and d.src ~= GetPlayerServerId(PlayerId()) then sound(Config.Sounds.win, L.wheel) end
    end
end)

-- ============================================
-- Near and far
-- ============================================

local function goLive()
    local W = Config.Wheel
    local base = GetClosestObjectOfType(W.coords.x, W.coords.y, W.coords.z, 2.0, joaat(W.base), false, false, false)
    local owned = false
    if base == 0 then
        if not W.spawnBase then return end
        local h = loadModel(W.base)
        if not h then return end
        base = CreateObjectNoOffset(h, W.coords.x, W.coords.y, W.coords.z, false, false, false)
        SetModelAsNoLongerNeeded(h)
        SetEntityHeading(base, W.heading)
        FreezeEntityPosition(base, true)
        owned = true
    end
    local h = loadModel(W.wheel)
    if not h then return end
    local L = {
        base = base, ownedBase = owned, heading = GetEntityHeading(base), angle = 0.0,
        interior = GetInteriorFromEntity(base), room = GetRoomKeyFromEntity(base),
    }
    local p = GetOffsetFromEntityInWorldCoords(base, W.wheelOffset.x, W.wheelOffset.y, W.wheelOffset.z)
    L.wheel = CreateObjectNoOffset(h, p.x, p.y, p.z, false, false, false)
    SetModelAsNoLongerNeeded(h)
    FreezeEntityPosition(L.wheel, true)
    intoRoom(L, L.wheel)
    if owned then intoRoom(L, base) end
    Live = L
    setAngle(L, 0.0)

    exports.whip_core:AddAction({
        id = 'luckywheel', group = 'luckywheel',
        at = { coords = GetOffsetFromEntityInWorldCoords(base, 0.0, -0.9, 1.0) },
        label = (Config.Spin.cost or 0) > 0 and ('Spin the Lucky Wheel (%s chips)'):format(Config.Spin.cost) or 'Spin the Lucky Wheel',
        icon = 'dollar',
        reach = Config.Reach,
        canInteract = function()
            return Using == nil and (not L.busy or L.busy == GetPlayerServerId(PlayerId()))
        end,
        onSelect = function() CreateThread(function() stepUp(L) end) end,
    })

    local snap = exports.whip_core:Callback('whip_luckywheel:snapshot')
    if Live ~= L then return end
    if type(snap) == 'table' then
        L.angle = tonumber(snap.angle) or 0.0
        L.busy = snap.busy
        if type(snap.spin) == 'table' then
            runSpin(L, snap.spin, snap.spin.elapsed)
        else
            setAngle(L, L.angle)
        end
        makePodium(L, snap.car)
    end
end

local function goDark()
    local L = Live
    if not L then return end
    Live = nil
    exports.whip_core:RemoveActionGroup('luckywheel')
    gone(L.wheel)
    gone(L.car)
    gone(L.podium)
    if L.ownedBase then gone(L.base) end
    if L.podiumMap and DoesEntityExist(L.podiumMap) then SetEntityVisible(L.podiumMap, true, false) end
end

CreateThread(function()
    while true do
        local d = #(GetEntityCoords(PlayerPedId()) - Config.Wheel.coords)
        if d <= Config.DrawRange and not Live then
            goLive()
        elseif d > Config.DrawRange + 10.0 and Live and not Using then
            goDark()
        elseif Live then
            -- The map can stream its stand out from under the wheel, or the podium back in.
            if not DoesEntityExist(Live.base) then goDark()
            elseif Live.podiumMap and DoesEntityExist(Live.podiumMap) then SetEntityVisible(Live.podiumMap, false, false) end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Using then
        exports.whip_core:HideText()
        if Using.camera then exports.whip_core:StopCamera() end
        ClearPedTasks(PlayerPedId())
    end
    goDark()
end)

-- /lwspin [segment] [turn] (dev): spin the wheel in this game only, to check where each segment stops. turn: try a
-- Config.Wheel.turn (degrees) for this spin, without restarting.
RegisterCommand('lwspin', function(_, args)
    local L = Live
    if not L or #(GetEntityCoords(PlayerPedId()) - Config.Wheel.coords) > 12.0 then
        return notify('Stand at the Lucky Wheel first', 'error')
    end
    local seg = math.floor(tonumber(args[1]) or math.random(SEG))
    if seg < 1 or seg > SEG then return notify(('A segment from 1 to %d'):format(SEG), 'error') end
    local turn = tonumber(args[2])
    local target = -(seg - 1) * STEP
    local from = L.angle
    local to = from - (Config.Timing.turns * 360.0 + (from - target) % 360.0)
    notify(('Segment %d: Config.Segments says %s%s'):format(seg, Config.Segments[seg].label,
        turn and (', wheel turned %.2f'):format(turn) or ''), 'inform')
    runSpin(L, { from = from, to = to, pull = 0, ms = Config.Timing.spinMs }, 0, turn)
end, false)
