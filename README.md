# whip_luckywheel

The casino's Lucky Wheel on whip. Step up to the wheel, pull the handle with GTA's own moves, and watch GTA's own wheel slow onto your prize. Everyone nearby sees it stop on the same segment. One spin a day per character, and every prize is paid through whip, so it's on the activity log.

## How it plays

1. **Step up.** At the wheel, press **E** on *Spin the Lucky Wheel*. You walk to the handle and raise an arm.
2. **Spin.** Press **Enter** or **left click**. **Backspace** steps away without spinning, and that doesn't use your spin.
3. **Win.** The camera watches the wheel go round. When it stops you're paid and celebrate, more for a bigger prize.

Only one player can use the wheel at a time. Someone who steps up and doesn't spin within a minute is let go.

## Prizes (Config.Segments)

The wheel has 20 segments. `Config.Segments` lists them in the order they're printed, each with a label, a weight (how likely it is) and a prize:

| Prize | Gives |
| --- | --- |
| `chips` | Casino Chips (`Config.Money.currency`) |
| `cash` | Cash in hand |
| `item` | Any registered item |
| `vehicle` | A car of their own, in their garage with its key. It's also the car turning on the podium |
| `mystery` | One of `Config.Mystery`, drawn by its weights |
| `nothing` | Nothing |

- **What's printed vs. what pays.** The print is a texture in k4mb1's map (`stream/extra/vw_prop_vw_luckywheel.ytd`, `prop_luckywheel_decal_d`), so the config can't change it. The defaults pay what k4mb1's wheel shows: cash, chips, DRINKS (5 of whip_core's `drink`), NOTHING, RANDOM and the vehicle. To print other prizes, edit that texture in OpenIV or CodeWalker, then match `Config.Segments` to it.
- **Default values.** The defaults are the amounts printed on the wheel (€50,000 at most), which may be a lot for your economy. You can lower them, but then the print overstates the prize.
- **Leaving mid-spin.** A player who disconnects while the wheel turns is still paid, to their character. A car won that way, or one that couldn't be made, is made at their next login.

## Cost and cooldown (Config.Spin)

- `cost`: what a spin costs, in chips. 0 is free, as in GTA.
- `cooldownHours`: how long a character waits between spins (24). It's saved with the character, so restarts and relogs don't reset it.
- If the resource stops mid-spin, the spin is given back: both the cost and the cooldown.

## The wheel and the podium

- **The wheel.** k4mb1 places the wheel's stand (`vw_prop_vw_luckywheel_01a`, entity set `k4_luckywheel2`) but not the wheel itself. This resource puts GTA's wheel (`vw_prop_vw_luckywheel_02a`) on the stand.
- **The podium.** The car turns on k4mb1's own podium. The map's podium can't move, so a copy replaces it while you're near. Set `Config.Podium.spin = false` to leave the podium still, or `enabled = false` for no car.
- **Chips.** Chips are whip_blackjack's `casino_chips` item, so run whip_blackjack alongside, or set `Config.Money.currency = nil` to pay cash.
- **sf-luckywheel.** Don't run sf-luckywheel at the same time.

## Setting it up

1. Put `whip_luckywheel` in resources, and `ensure whip_luckywheel` after whip_core and whip_blackjack.
2. **Check the segments:** stand at the wheel and run `/lwspin 1` (any segment from 1 to 20). It spins in your game only, and says what `Config.Segments` expects there.

| If you see | Fix |
| --- | --- |
| The pointer stops between two prizes, or always one over | Try `/lwspin 1 9` (a turn in degrees; 18 is one segment), then put the right one in `Config.Wheel.turn` |
| It stops on a different prize than listed | Reorder `Config.Segments`. Tell me what segments 1 and 2 land on |
| The wheel floats off its stand, or sits inside it | `Config.Wheel.wheelOffset` |
| You stand beside the handle, not at it | `Config.Wheel.standOffset` / `standTurn` |
| The car floats or sinks on the podium | `Config.Podium.carUp` |
