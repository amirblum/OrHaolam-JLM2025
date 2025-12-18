# JLM LOTW Requirements

concept
Jerusalem sits at the middle of the world, engulfed in light
the whole world is in the darkness
other cities in the world, when in the darkness, rot, and create sad zombie people
the people move towards jerusalem to steal her light
Jerusalem puts out beams of light the build slowly
the beams of light stops people in their tracks and make them dance
when people dance they turn happy and increase the light
when the light fades the people turn to zombies and march on Jerusalem again
when the light in the world is high enough, Jerusalem Beams increase in power
until the whole world is engulfed in light

an angle based tower defence clicker game
all interaction is mouse / SPACE click, click-and-hold, or auto click be mouse position for increasing light

Input generates "click tick"
If input is click and hold, and the power up `hold_enable` is true, generates repeated "click ticks" at a configurable rate (`auto_click_rate`).
A powerup can enable `auto_click` so click ticks happen even when not holding.


# Quick Summary of Core Mechanics:

## Player Input:
Click to generate one click tick
Hold (mouse LMB or SPACE) to generate repeated click ticks at `auto_click_rate` (upgradeable).
Each click tick uses the current mouse position as the pointer → calculate clickPoint angle from Jerusalem center.
Hold-enable powerup: allow auto clicking only if `hold_enable` is true
Auto-click powerup: if `auto_click` is true, click ticks happen even without holding.

Hit existing Beam: Expand it by exactly `clickImpact` degrees total per click tick, divided asymmetrically based on click position (biased toward the nearer edge; equal if perfectly centered).
Miss all Beams (darkness): Spawn new Beam centered on click angle, sized by fixed `clickImpact`.

## Beams (light sectors):
Implemented as center angle + width (code uses radians). For design/math, treat it as `[min,max]` where `min = center - width/2`, `max = center + width/2` in an unwrapped angle space.
Auto-shrink at lightDecay rate.
Merge on touch or overlap (combine into single Beam with overall min/max).

Note: Beams are expected to often cross 0°, so contains/merge checks must be done in an "unwrapped" angle space relative to the click / beam center.

Beam hit test (implemented):
- A click tick "hits" a Beam only if the pointer is within the Beam radius (`coneRadius`) AND within its angular span.
- Click ticks too close to the center (within `minClickDist`) are ignored.

## Cities (e.g., Amsterdam, Rome):
Orbit screen edges (x, y positions).
In darkness → rot builds → spawn Persons faster (rate scales with rot; TODO: full spawn logic, e.g., at cityGenRadius?).
Its angle from the center is inside a Beam (checked with a small angular tolerance) → rot drops fast via cityCureRate.

## Persons (zombies/dancers):
Spawn from rotty Cities.
Dark state (outside Beams) → pulse-move toward Jerusalem every movePulseSpeed secs:
Step walkDistance at direct angle + drunkness randomness (for wobbly paths).
If they'd enter JerusalemRadius → steal lightSteal from lightBank instead.

## Light state (inside Beam) → dance.
After danceThreshold time → happy state → generate dancingLight per sec into lightBank.
Upgrades? lightBank likely boosts clickImpact.

## Win/Loss Loop:
Goal: Flood world with light via expanding Beams → cure Cities → convert Persons → snowball lightBank → stronger Beams.
Risk: Zombies reach Jerusalem → drain lightBank; unchecked rot = zombie hordes.
Jerusalem starts with tiny innate light circle.


# Data Flow (High-Level Pseudocode for Clarity):
On Click Tick (from hold / auto-click):
  angle = atan2(clickPoint.y - center.y, clickPoint.x - center.x)  # 0° up, etc.
  if in_beam = find_beam_containing(angle):
    bias = calc_tilt_percent(angle, in_beam.min, in_beam.max)
    expand_beam_asymmetrically(in_beam, clickImpact, bias) # e.g., more toward closer edge
  else:
    beams.append(new Beam(angle - impact/2, angle + impact/2))
  merge_touching_or_overlapping_beams()

Tick (per frame/sec):
  shrink_all_beams(lightDecay)
  update_Persons()  # check Beam coverage → state changes, moves, light gen
  update_cities()   # check Beam submersion → rot +/- 
  spawn_Persons_from_rotty_cities()


# data set

`Beams` - a list of **Beam** objects
    - (implementation) `center` angle (`direction_rad`)
    - (implementation) `width` (`angle_spread_rad`)
    - (derived for math) `min` = center - width/2
    - (derived for math) `max` = center + width/2
    - `coneRadius` - how far the beam reaches from the center (radius)

`Persons` - list of **Person** objects
    - `STATE`
    - `happyTime` - the amount of time the **Person** is dancing

`danceThreshold` - time in light before a Person becomes happy
`dancingLight` - light added to `lightBank` per second by each happy Person

`CITY_SIZE` - the width of the city for the light check

`clickImpact` - how much light is created per click
`lightDecay` - how fast a BEAM shrinks per second
`lightBank` - how much light currency the player has

`auto_click_rate` - click ticks per second while holding / auto-clicking
`auto_click` - if true, click ticks happen without holding (powerup/upgrade hook)

`minClickDist` - minimum distance from center for a click tick to register

`JerusalemRadius` - the distance at which **Person** steal light from it
`clickPoint` - x,y of mouse click
`cityGenRadius` - the distance range from the city at which the city generates **Person**
`cityCureRate` - the rate at which cities cure from rot
`movePulseSpeed` - the rate of **Person** movement towards Jerusalem
`walkDistance` - the distance the **Person** moves each time
`drunkness` - the factor at which **Person** are deviating from walking in a straight line towards jerusalem
`lightSteal` - the amount of light lost when a Person touches Jerusalem


# interaction
- Player clicks screen (mouse LMB or SPACE, mouse position is the pointer)
    - one click tick is happens
    - while held, if `hold_enable`, repeated click ticks occur at `auto_click_rate` (or continuously if `auto_click` is enabled)
    - each click tick calculates a `clickPoint` (mouse position) and its angle from the center
    - if the `clickPoint` hits an existing **Beam** (within radius + angular span), the **Beam** expands in size
        - the click angle is evaluated against the Beam's derived `min` and `max` (in an unwrapped space)
        - the Beam expands in relation to how close the click is to either min or max
            - if the click is exactly in the middle, expansion is equal on both sides
            - if the click is closer to one edge, expansion is biased toward that edge
            - The total width of the Beam increases by exactly `clickImpact` degrees per click tick. This added width is divided between the two sides according to the bias percentage (closer to one edge = more expansion on that side)
    - if the click tick is in the darkness (NOT in any **Beam**) a new **Beam** is created 
    - after each click tick, all Beams are merged if any touch/overlap

**Beam**
- the **Beam** is angle-based, implemented as `center` + `width` (min/max derived)
- When creating a new **Beam** in darkness, it is centered on the click angle with initial width exactly equal to `clickImpact` degrees.
- if two **Beam** touch or overlap they merge into one beam 
- the **Beam** is expanding by `clickImpact` each click tick when hit
- the **Beam** shrinks at `lightDecay` speed constantly

**Jerusalem**
- sits at the center of screen emiting light
- surrounded by a tiny circle of light

**city**
- has `name` : (Amsterdam, Rome, New York, Delhi etc.)
- has `rot` level
- sits around the peripheral of the screen (`x`, `y`)
- when in the dark, (NOT within any **Beam**) starts to increase in `rot`
- when `rot` > 0, city generates **Person**
    - New Person spawns at a random position within `cityGenRadius` distance from the city
    - Starts with no velocity (movement is fully handled by the pulse system)"
- the more `rot` the quicker the city generates **Person** (TODO: explain the system)
- when the **city** is in the light (its angle from the center falls within one of the **Beam** ranges, checked using the city's x,y position and a small constant angular tolerance ± a few degrees (const `CITY_SIZE`) the `rot` drops rapidly by `cityCureRate` 

**Person**
- has `STATE` (dark/light/happy)
- when a **Person** is within the light of a **Beam** it changes to `STATE` light and starts dancing
- when **Person** is in light for `danceThreshold` time it changes to happy `STATE`
- when in happy `STATE` **Person** adds `dancingLight` to `lightBank` per second
- when **Person** in darkness (NOT in any **Beam**) change to dark `STATE`
- when **Person** is dark, starts moving towards jerusalem
-- **Person** moves in pulses
-- a pulse happens every `movePulseSpeed` seconds
-- the **Person** moves a short `walkDistance` towards a random angle
-- the random angle is the angle between the **Person** and Jerusalem + a random factor `drunkness`
-- if a Person is to move into `JerusalemRadius` distance from Jerusalem, he does not move, `lightBank` is decreased by `lightSteal` instead

---
Implementation mapping (current repo):
- `scenes/player/Player.gd`: owns the active Beams list, click tick loop (hold + `auto_click_rate`), hit-test selection, spawn, and merge-on-touch.
- `scenes/cone/Cone.gd`: Beam geometry + drawing, shrink (`lightDecay`), hit-test helper, and biased expansion by `clickImpact`.
- `scenes/main/Main.gd`: currently only handles quitting (Escape).

