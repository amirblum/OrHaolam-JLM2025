# JLM LOTW Requirements

concept
Jerusalem sits at the middle of the world, engulfed in light
the whole world is in the darkness
other cities in the world, when in the darkness, rut, and create sad zombie people
the people move towards jerusalem to steal her light
Jerusalem puts out beams of light the build slowly
the beams of light stops people in their tracks and make them dance
when people dance they turn happy and increase the light
when the light fades the people turn to zombies and march on Jerusalem again
when the light in the world is high enough, Jerusalem Beams increase in power
until the whole world is engulfed in light

an angle based tower defence clicker game
all interaction is rapid clicking for light


# Quick Summary of Core Mechanics:

## Player Input:
Rapid clicks (mouse or SPACE + mouse) anywhere on screen → calculate clickPoint angle from Jerusalem center.
Hit existing Beam: Expand it Expand it by exactly clickImpact degrees total, divided asymmetrically based on click position (biased toward the nearer edge; equal if perfectly centered).
Miss all Beams (darkness): Spawn new Beam centered on click angle, sized by fixed clickImpact.

## Beams (light sectors):
Defined by min/max angles (direction + width).
Auto-shrink at lightDecay rate.
Merge on overlap (combine into single Beam with overall min/max).

## Cities (e.g., Amsterdam, Rome):
Orbit screen edges (x, y positions).
In darkness → rut builds → spawn Persons faster (rate scales with rut; TODO: full spawn logic, e.g., at cityGenRadius?).
Its angle from the center is inside a Beam (checked with a small angular tolerance) → rut drops fast via cityCureRate.

## Persons (zombies/dancers):
Spawn from rutty Cities.
Dark state (outside Beams) → pulse-move toward Jerusalem every movePulseSpeed secs:
Step walkDistance at direct angle + drunkness randomness (for wobbly paths).
If they'd enter JerusalemRadius → steal lightSteal from lightBank instead.

## Light state (inside Beam) → dance.
After danceThreshold time → happy state → generate dancingLight per sec into lightBank.
Upgrades? lightBank likely boosts clickImpact.

## Win/Loss Loop:
Goal: Flood world with light via expanding Beams → cure Cities → convert Persons → snowball lightBank → stronger Beams.
Risk: Zombies reach Jerusalem → drain lightBank; unchecked rut = zombie hordes.
Jerusalem starts with tiny innate light circle.


# Data Flow (High-Level Pseudocode for Clarity):
textOn Click:
  angle = atan2(clickPoint.y - center.y, clickPoint.x - center.x)  # 0° up, etc.
  if in_beam = find_beam_containing(angle):
    bias = calc_tilt_percent(angle, in_beam.min, in_beam.max)
    expand_beam_asymmetrically(in_beam, clickImpact, bias) # e.g., more toward closer edge
  else:
    beams.append(new Beam(angle - impact/2, angle + impact/2))
  merge_overlapping_beams()

Tick (per frame/sec):
  shrink_all_beams(lightDecay)
  update_Persons()  # check Beam coverage → state changes, moves, light gen
  update_cities()   # check Beam submersion → rut +/- 
  spawn_Persons_from_rutty_cities()


# data set

`Beams` - a list of **Beam** objects
    - `min` angle
    - `max` angle

`Persons` - list of **Person** objects
    - `STATE`
    - `happyTime` - the amount of time the **Person** is dancing

`danceThreshold` - time in light before a Person becomes happy
`dancingLight` - light added to `lightBank` per second by each happy Person

`CITY_SIZE` - the width of the city for the light check

`clickImpact` - how much light is created per click
`lightDecay` - how fast a BEAM shrinks per second
`lightBank` - how much light currency the player has

`JerusalemRadius` - the distance at which **Person** steal light from it
`clickPoint` - x,y of mouse click
`cityGenRadius` - the distance range from the city at which the city generates **Person**
`cityCureRate` - the rate at which cities cure from rut
`movePulseSpeed` - the rate of **Person** movement towards Jerusalem
`walkDistance` - the distance the **Person** moves each time
`drunkness` - the factor at which **Person** are deviating from walking in a straight line towards jerusalem
`lightSteal` - the amount of light lost when a Person touches Jerusalem


# interaction
- Player presses screen (mouse click or SPACE + mouse as pointer)
    - a `clickPoint` is calculated
    -   if the `clickPoint` is within one of the **Beam** of light the **Beam** expands in size
        - the `clickpoint` is checked against the **Beam**s `min` and `max`
        - the **Beam** expands in relation to how close the click is to either min or max
            - if the `clickPoint` is exactly at the middle between min and max, the **Beam** expands equally on both sides
            - if the `clickPoint` is leaning towards the min or max the expansion is divided by the % of the leaning
            - The total width of the Beam increases by exactly `clickImpact` degrees. This added width is divided between the two sides according to the bias percentage (closer to one edge = more expansion on that side)
    -   if the press is in the darkness (NOT in any **Beam**) a new **Beam** is created 

**Beam**
- the **Beam** is angle based, and has `MIN` and `MAX` angles to state both direction and size
- When creating a new **Beam** in darkness, it is centered on the click angle with initial width exactly equal to `clickImpact` degrees.
- if two **Beam** overlap they merge into one beam 
- the **Beam** is expanding by `clickImpact` when clicked
- the **Beam** shrinks at `lightDecay` speed constantly

**Jerusalem**
- sits at the center of screen emiting light
- surrounded by a tiny circle of light

**city**
- has `name` : (Amsterdam, Rome, New York, Delhi etc.)
- has `rut` level
- sits around the peripheral of the screen (`x`, `y`)
- when in the dark, (NOT within any **Beam**) starts to increase in `rut`
- when `rut` > 0, city generates **Person**
    - New Person spawns at a random position within `cityGenRadius` distance from the city
    - Starts with no velocity (movement is fully handled by the pulse system)"
- the more `rut` the quicker the city generates **Person** (TODO: explain the system)
- when the **city** is in the light (its angle from the center falls within one of the **Beam** ranges, checked using the city's x,y position and a small constant angular tolerance ± a few degrees (const `CITY_SIZE`) the `rut` drops rapidly by `cityCureRate` 

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

