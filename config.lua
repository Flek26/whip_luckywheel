Config = {}

-- ============================================
-- Money
-- ============================================
-- Chip prizes and the spin's cost (if any) are in this currency: 'casino_chips' is whip_blackjack's chips item,
-- cashed in at its cashier, so run whip_blackjack too. nil = plain cash. Cash prizes are always cash.
Config.Money = {
    method   = 'cash',
    currency = 'casino_chips',
}

-- ============================================
-- The spin
-- ============================================
--   cost:          what a spin costs, in Config.Money's currency. 0 = free, as in GTA.
--   cooldownHours: how long a character waits between spins (kept with the character, so it survives restarts
--                  and relogs). 0 = no wait.
Config.Spin = {
    cost          = 0,
    cooldownHours = 24,
}

-- ============================================
-- The wheel
-- ============================================
-- base: the wheel's stand, already in the map (k4mb1 has it in entity set k4_luckywheel2). We find it there and put
-- GTA's wheel (vw_prop_vw_luckywheel_02a, the part that turns) on it, offset from the stand as in GTA's casino.
-- spawnBase = true places the stand too, at coords / heading, for a casino without one.
Config.Wheel = {
    base        = 'vw_prop_vw_luckywheel_01a',
    wheel       = 'vw_prop_vw_luckywheel_02a',
    coords      = vec3(964.640, 49.320, 80.557),   -- k4mb1's stand, read out of k4mb1_casino2.ytyp
    heading     = 238.0,                           -- only used with spawnBase
    spawnBase   = false,
    wheelOffset = vec3(0.0, 0.0087, 1.5079),       -- the wheel's middle, from the stand
    -- Degrees: turns the wheel's print against where it stops. /lwspin <segment> (dev) spins one in your game: if
    -- the pointer stops between two prizes, or on the one next door, this is what to change (18 is one segment).
    turn        = 0.0,
    -- GTA's lucky wheel moves are played from the stand's origin. If you stand off the handle, nudge them:
    -- metres in the stand's own frame (x right, y away from the wheel... -y is towards you), and degrees.
    standOffset = vec3(0.0, 0.0, 0.0),
    standTurn   = 0.0,
}

-- ============================================
-- The prizes, round the wheel
-- ============================================
-- The wheel has 20 segments, and this is each one in order, as the wheel is printed (segment 1 is where the wheel
-- starts). /lwspin <1-20> (dev) checks one: it says what this list expects, and the wheel stops on what's printed.
--
-- label:  what the player is told they won
-- weight: how likely, against the others (they needn't add up to anything)
-- prize:  { type = 'chips', amount }      Config.Money.currency (casino chips)
--         { type = 'cash', amount }       cash in hand
--         { type = 'item', item, amount } any registered item
--         { type = 'vehicle', model }     a car of their own, in their garage with its key (shown on the podium)
--         { type = 'mystery' }            one of Config.Mystery, drawn by its weights
--         { type = 'nothing' }
--
-- The print is a texture in k4mb1's map (stream/extra/vw_prop_vw_luckywheel.ytd, prop_luckywheel_decal_d): this list
-- can't change what's printed, only what each segment pays. Keep the two matching. Going clockwise from 2,500:
-- the $ segments pay cash, the money bags (printed in euros) cash, the chip stacks chips, DRINKS whip_core's drink.
Config.Segments = {
    { label = '$2,500',             weight = 10,  prize = { type = 'cash',  amount = 2500 } },
    { label = '$20,000',            weight = 3,   prize = { type = 'cash',  amount = 20000 } },
    { label = '10,000 chips',       weight = 5,   prize = { type = 'chips', amount = 10000 } },
    { label = 'Nothing',            weight = 6,   prize = { type = 'nothing' } },
    { label = '$5,000',             weight = 8,   prize = { type = 'cash',  amount = 5000 } },
    { label = '$30,000',            weight = 2,   prize = { type = 'cash',  amount = 30000 } },
    { label = '15,000 chips',       weight = 4,   prize = { type = 'chips', amount = 15000 } },
    { label = 'Drinks',             weight = 8,   prize = { type = 'item',  item = 'drink', amount = 5 } },
    { label = '$7,500',             weight = 6,   prize = { type = 'cash',  amount = 7500 } },
    { label = '20,000 chips',       weight = 3,   prize = { type = 'chips', amount = 20000 } },
    { label = 'a Random prize',     weight = 3,   prize = { type = 'mystery' } },
    { label = 'Drinks',             weight = 8,   prize = { type = 'item',  item = 'drink', amount = 5 } },
    { label = '$10,000',            weight = 4,   prize = { type = 'cash',  amount = 10000 } },
    { label = '$40,000',            weight = 1.5, prize = { type = 'cash',  amount = 40000 } },
    { label = '25,000 chips',       weight = 2,   prize = { type = 'chips', amount = 25000 } },
    { label = 'Drinks',             weight = 8,   prize = { type = 'item',  item = 'drink', amount = 5 } },
    { label = '$15,000',            weight = 2,   prize = { type = 'cash',  amount = 15000 } },
    { label = 'the Podium Vehicle', weight = 0.5, prize = { type = 'vehicle', model = 'zentorno' } },
    { label = '$50,000',            weight = 1,   prize = { type = 'cash',  amount = 50000 } },
    { label = 'Drinks',             weight = 8,   prize = { type = 'item',  item = 'drink', amount = 5 } },
}

-- The RANDOM segment draws one of these.
Config.Mystery = {
    { label = '$10,000',      weight = 5, prize = { type = 'cash',  amount = 10000 } },
    { label = '5,000 chips',  weight = 6, prize = { type = 'chips', amount = 5000 } },
    { label = '50,000 chips', weight = 1, prize = { type = 'chips', amount = 50000 } },
    { label = 'nothing',      weight = 2, prize = { type = 'nothing' } },
}

-- A prize worth this much or more gets the big celebration, and huge the biggest (a car always does).
Config.Celebrate = { big = 15000, huge = 40000 }

-- ============================================
-- The podium
-- ============================================
-- The car you can win, turning on the casino's podium (k4mb1's own, read out of its map files). The car is the
-- first 'vehicle' prize in Config.Segments. spin = true turns the podium with it: the map's podium can't move, so a
-- copy goes in its place and the map's is hidden while you're near.
Config.Podium = {
    enabled  = true,
    model    = 'k4mb1_casino2_podium',
    coords   = vec3(970.030, 45.990, 80.515),
    carUp    = 1.07,    -- the car above the podium's origin
    spin     = true,
    perSec   = 6.0,     -- degrees a second
    colours  = nil,     -- { primary, secondary } GTA colour ids; nil = a random one each restart
}

-- ============================================
-- Timing (ms)
-- ============================================
Config.Timing = {
    pullMs  = 700,     -- the arm coming down, before the wheel moves
    spinMs  = 10000,   -- the wheel turning, start to stop
    turns   = 4,       -- whole turns before it slows onto the prize
    holdMs  = 60000,   -- how long someone can stand at the wheel without spinning, before it's let go
}

-- ============================================
-- At the wheel
-- ============================================
-- The camera on the wheel while it turns, from in front of it.
Config.Camera = {
    enabled = true,
    back    = 3.4,   -- in front of the wheel
    up      = 0.0,   -- above its middle
    fov     = 50.0,
}

-- The sounds: GTA's own, from the casino's audio. Set bank = nil for none.
Config.Sounds = {
    bank = 'DLC_VINEWOOD/CASINO_GENERAL',
    set  = 'dlc_vw_casino_lucky_wheel_sounds',
    tick = 'Spin_Single_Ticks',
    win  = 'Win',
}

Config.Keys = {
    spin  = { key = 191, pad = 201, text = 'Enter',     button = 'a' },   -- or left click
    leave = { key = 194, pad = 202, text = 'Backspace', button = 'b' },
}

Config.Reach     = 2.2    -- how close to the wheel the prompt shows
Config.DrawRange = 60.0   -- the wheel and podium car are made within this
Config.SyncRange = 70.0   -- players this close see each spin
