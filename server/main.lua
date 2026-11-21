-- ============================================
-- whip_luckywheel — server: who's at the wheel, the cooldown, the draw, the prize
-- ============================================
--
-- One player at the wheel at a time. The server draws the segment when they spin and tells every game nearby how
-- the wheel turns (from where, to where, how long), so everyone sees it stop on the same prize. The prize is paid
-- when it stops. The cooldown is kept in the character's metadata, so it survives restarts and relogs.

local LAST = 'whip_luckywheel_last'   -- os.time() of the character's last spin
local OWED = 'whip_luckywheel_owed'   -- cars won but not yet made (they left mid-spin, or making it failed)
local SEG = #Config.Segments
local STEP = 360.0 / SEG
local TM = Config.Timing

local W = {
    user = nil,       -- { src, charId, name, phase = 'ready' | 'spinning', since, receipt, prev, dropped }
    angle = 0.0,      -- where the wheel is now, in degrees (segment 1 at 0, segment n at -(n-1) * STEP)
    spinning = nil,   -- { from, to, at }
}
local WHEEL_POS = Config.Wheel.coords + vector3(0.0, 0.0, Config.Wheel.wheelOffset.z)

local function now() return GetGameTimer() end

local function notify(src, msg, kind) Whip.core:NotifyPlayer(src, msg, kind or 'inform') end

local function Fx(kind, data)
    for _, s in ipairs(Whip.core:GetPlayersInRange(WHEEL_POS, Config.SyncRange) or {}) do
        TriggerClientEvent('whip_luckywheel:fx', s, kind, data)
    end
end

-- ============================================
-- The car on the podium
-- ============================================

local function podiumCar()
    for _, s in ipairs(Config.Segments) do
        if s.prize.type == 'vehicle' then return s.prize.model end
    end
end

local NICE = { 0, 1, 27, 29, 35, 38, 42, 44, 49, 53, 55, 61, 64, 70, 88, 89, 92, 111, 120, 135, 137, 145, 158 }
local function podiumColours()
    if Config.Podium.colours then return Config.Podium.colours end
    local c = NICE[math.random(#NICE)]
    return { c, c }
end
W.car = podiumCar() and { model = podiumCar(), colours = podiumColours() } or nil

-- ============================================
-- The cooldown
-- ============================================

local function waitLeft(who)
    local hours = Config.Spin.cooldownHours or 0
    if hours <= 0 then return 0, nil end
    local raw = Whip.core:GetPlayerMetadata(who, LAST)   -- returns nothing at all for a key never set
    local last = tonumber(raw)
    if not last then return 0, nil end
    return math.max(0, last + math.floor(hours * 3600) - os.time()), last
end

local function untilText(secs)
    local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60)
    if h > 0 then return ('%dh %02dm'):format(h, m) end
    if m > 0 then return ('%d minutes'):format(m) end
    return 'a moment'
end

-- ============================================
-- The draw
-- ============================================

local function draw(list)
    local sum = 0
    for _, e in ipairs(list) do sum = sum + math.max(0, e.weight or 0) end
    if sum <= 0 then return math.random(#list) end
    local r = math.random() * sum
    for i, e in ipairs(list) do
        r = r - math.max(0, e.weight or 0)
        if r <= 0 then return i end
    end
    return #list
end

--- How big a celebration a prize gets.
local function celebration(prize)
    if prize.type == 'nothing' then return 'lose' end
    if prize.type == 'vehicle' then return 'huge' end
    local v = (prize.type == 'chips' or prize.type == 'cash') and (prize.amount or 0) or 0
    if v >= Config.Celebrate.huge then return 'huge' end
    if v >= Config.Celebrate.big then return 'big' end
    return 'win'
end

-- ============================================
-- Paying
-- ============================================

local function owe(who, model)
    local list = Whip.core:GetPlayerMetadata(who, OWED)
    list = type(list) == 'table' and list or {}
    list[#list + 1] = model
    local ok, why = Whip.core:SetPlayerMetadata(who, OWED, list)
    if not ok then
        print(('[whip_luckywheel] CRITICAL: could not note the %s owed to %s: %s'):format(model, json.encode(who), tostring(why)))
    end
end

local function giveCar(src, model)
    local id, why, saved = Whip.core:CreateOwnedVehicle(src, { model = model }, { giveKey = true })
    if id or saved then return true end
    print(('[whip_luckywheel] could not make the %s for %d: %s (owed at next login)'):format(model, src, tostring(why)))
    return false
end

local function award(U, prize, label)
    local who = U.dropped and { charId = U.charId } or U.src
    local reason = 'Lucky Wheel: ' .. label
    local t = prize.type
    local ok, why = true, nil
    if t == 'chips' or t == 'cash' then
        local opts = { reason = reason }
        if t == 'chips' and Config.Money.currency then opts.currency = Config.Money.currency end
        if not U.dropped then opts.method = (t == 'chips') and Config.Money.method or 'cash' end
        ok, why = Whip.core:PayPlayer(who, math.floor(prize.amount or 0), opts)
    elseif t == 'item' then
        ok, why = Whip.core:GiveOnLogin(who, prize.item, math.floor(prize.amount or 1), nil, { reason = reason })
    elseif t == 'vehicle' then
        if U.dropped or not giveCar(U.src, prize.model) then owe(who, prize.model) end
    end
    if not ok then
        print(('[whip_luckywheel] CRITICAL: could not give %s (char %s) %s: %s'):format(U.name, tostring(U.charId), label, tostring(why)))
    end
    return ok
end

-- Cars owed from before: made at login.
AddEventHandler('whip_core:player:loaded', function(e)
    local src = type(e) == 'table' and e.source
    if not src then return end
    CreateThread(function()
        Wait(5000)
        local list = Whip.core:GetPlayerMetadata(src, OWED)
        if type(list) ~= 'table' or #list == 0 then return end
        local left = {}
        for _, model in ipairs(list) do
            if giveCar(src, model) then
                notify(src, 'Your Lucky Wheel car is waiting in your garage', 'success')
            else
                left[#left + 1] = model
            end
        end
        Whip.core:SetPlayerMetadata(src, OWED, left)
    end)
end)

-- ============================================
-- At the wheel
-- ============================================

local function release(reason)
    local U = W.user
    if not U then return end
    W.user = nil
    Fx('user', { src = false })
    if reason and not U.dropped then TriggerClientEvent('whip_luckywheel:stand', U.src, reason) end
end

local function use(src, player)
    if W.user then
        if W.user.src == src then return { cost = Config.Spin.cost } end
        return false, 'Someone is at the wheel'
    end
    if Whip.core:IsPlayerDead(src) == true then return false, 'Not now' end
    if #(GetEntityCoords(GetPlayerPed(src)) - Config.Wheel.coords) > Config.Reach + 2.5 then return false, 'Too far from the wheel' end
    local left = waitLeft(src)
    if left > 0 then return false, ('You can spin the wheel again in %s'):format(untilText(left)) end
    W.user = {
        src = src, charId = player.charId, name = player.fullName or GetPlayerName(src),
        phase = 'ready', since = now(),
    }
    Fx('user', { src = src })
    return { cost = Config.Spin.cost }
end

local function spin(src)
    local U = W.user
    if not U or U.src ~= src or U.phase ~= 'ready' then return false, 'Step up to the wheel first' end
    local left, prev = waitLeft(src)
    if left > 0 then
        release()
        return false, ('You can spin the wheel again in %s'):format(untilText(left))
    end

    -- Pay for it (if it costs), and start the cooldown, before anything is drawn.
    local cost = math.floor(Config.Spin.cost or 0)
    if cost > 0 then
        local opts = { reason = 'Lucky Wheel spin', method = Config.Money.method }
        if Config.Money.currency then opts.currency = Config.Money.currency end
        local receipt, why = Whip.core:ChargePlayer(src, cost, opts)
        if not receipt then
            release()
            return false, why or 'You can\'t pay for a spin'
        end
        U.receipt = receipt
    end
    if (Config.Spin.cooldownHours or 0) > 0 then
        local ok, why = Whip.core:SetPlayerMetadata(src, LAST, os.time())
        if not ok then
            if U.receipt then Whip.core:RefundPlayer(U.receipt) end
            release()
            return false, why or 'Try again in a moment'
        end
    end
    U.prev = prev
    U.phase = 'spinning'

    -- The draw, and where the wheel stops: on that segment, a little either side of its middle (never on a fret).
    local seg = draw(Config.Segments)
    local S = Config.Segments[seg]
    local prize, label = S.prize, S.label
    if prize.type == 'mystery' then
        local m = Config.Mystery[draw(Config.Mystery)]
        prize, label = m.prize, ('%s: %s'):format(S.label, m.label)
    end
    local target = -(seg - 1) * STEP + (math.random() * 2 - 1) * STEP * 0.38
    local from = W.angle
    local to = from - (TM.turns * 360.0 + (from - target) % 360.0)
    W.angle = to % 360.0
    W.spinning = { from = from, to = to, at = now() }
    Fx('spin', { from = from, to = to, pull = TM.pullMs, ms = TM.spinMs, src = src })

    CreateThread(function()
        Wait(TM.pullMs + TM.spinMs + 300)
        W.spinning = nil
        U.paid = true
        award(U, prize, label)
        local how = celebration(prize)
        Fx('stop', { src = src, how = how })
        if not U.dropped then
            local kind = prize.type == 'nothing' and 'error' or 'success'
            local msg = prize.type == 'nothing' and ('%s. Better luck tomorrow'):format(label)
                or (prize.type == 'vehicle' and ('You won %s! It\'s in your garage, key and all'):format(label)
                or ('You won %s!'):format(label))
            notify(src, msg, kind)
            TriggerClientEvent('whip_luckywheel:won', src, how)
        end
        print(('[whip_luckywheel] %s won %s (segment %d)'):format(U.name, label, seg))
        Wait(6000)
        if W.user == U then release() end
    end)
    return true
end

Whip.register(function()
    Whip.core:SecureCallback('whip_luckywheel:use', { rateLimit = 1000 }, use)
    Whip.core:SecureCallback('whip_luckywheel:spin', { rateLimit = 1000 }, function(source) return spin(source) end)
    Whip.core:SecureCallback('whip_luckywheel:snapshot', { rateLimit = 500, burst = 4 }, function()
        local sp = W.spinning
        return {
            angle = W.angle, busy = W.user and W.user.src or false, car = W.car,
            spin = sp and { from = sp.from, to = sp.to, pull = TM.pullMs, ms = TM.spinMs, elapsed = now() - sp.at } or nil,
        }
    end)
    Whip.core:SecureEvent('whip_luckywheel:leave', { rateLimit = 500, whileDead = true }, function(source)
        local U = W.user
        if U and U.src == source and U.phase == 'ready' then release() end
    end)

    SetTimeout(15000, function()
        local cur = Config.Money.currency
        if cur and not Whip.core:GetItemDef(cur) then
            print(('[whip_luckywheel] chip prizes are in "%s", but no such item exists: start whip_blackjack (it has the casino chips and the cashier), or set Config.Money.currency = nil to pay cash.'):format(cur))
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local U = W.user
    if not U or U.src ~= source then return end
    U.dropped = true
    if U.phase == 'ready' then release() end   -- mid-spin, it still stops and pays (to the character)
end)

-- Standing at the wheel too long, walking off or dying lets it go (before the spin only).
CreateThread(function()
    while true do
        Wait(1000)
        local U = W.user
        if U and U.phase == 'ready' and not U.dropped then
            local ped = GetPlayerPed(U.src)
            if now() - U.since > TM.holdMs then
                release('You took too long')
            elseif ped == 0 or #(GetEntityCoords(ped) - Config.Wheel.coords) > Config.Reach + 4.0 or Whip.core:IsPlayerDead(U.src) == true then
                release('away')
            end
        end
    end
end)

-- Stopping mid-spin: the spin is given back, the cost and the cooldown both.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local U = W.user
    if not U or U.phase ~= 'spinning' or U.paid then return end
    if U.receipt then Whip.core:RefundPlayer(U.receipt) end
    if (Config.Spin.cooldownHours or 0) > 0 then
        Whip.core:SetPlayerMetadata(U.dropped and { charId = U.charId } or U.src, LAST, U.prev or 0)
    end
end)

local function suggestions(src)
    if not IsPlayerAceAllowed(src, 'whip.devtools') then return end
    TriggerClientEvent('chat:addSuggestions', src, {
        { name = '/lwspin', help = 'Lucky Wheel: spin it here only, to check where each segment stops', params = {
            { name = 'segment', help = '1-' .. SEG .. ', or empty for a random one' },
            { name = 'turn', help = 'try a Config.Wheel.turn (degrees) for this spin' },
        } },
    })
end
AddEventHandler('whip_core:player:loaded', function(e) if type(e) == 'table' and e.source then suggestions(e.source) end end)
CreateThread(function() for _, s in ipairs(GetPlayers()) do suggestions(tonumber(s)) end end)

Whip.sayStarted()
