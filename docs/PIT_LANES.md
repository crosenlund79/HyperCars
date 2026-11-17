# Pit lanes, split sections, pit violations and vehicle lights

Approved 2026-11-17 ("HyperCars — Endurance Racing, Track Branches, Pit Violations,
Lighting & Steering"). Numbers are provisional (`src/race/default_pit_rules.tres`,
personality traits in `src/ai/personalities/`).

## Track branches (`TrackLayout.branches`)

A branch is a stretch where the road widens around a solid **divider** and later
merges back again. The divider is a barrier island with a rounded nose at each end.
Lap progress stays a projection onto the centreline, so every lane counts laps,
positions, gaps and timing in the same way. Checkpoint gates span every lane.
`TrackLayout.validate_branches()` keeps branches:
- on the ground;
- clear of jumps, narrow sections and the starting grid;
- at least 80 px from any other stretch of road.

| Circuit | Pit lane (arc px) | Service box | Split section | Split lanes (left / right) |
|---|---|---|---|---|
| Kestrel Ridge | 250–1350, main straight, right | 800 | 5430–6070 (west loop straight) | 96 / 96: equal |
| Larkspur Ring | 300–1500, main straight, right | 900 | 4150–4950 (through a bend) | 84 / 112: tight inside or fast-but-wide outside |
| Ravenhook | 250–1350, main straight, right | 800 | 7650–8320 | 112 / 84: wide left or narrow right |

All three pit lanes use the same dimensions:
- 280 px entry and exit ramps;
- a 72 px lane;
- a 24 px divider;
- a 90 px service box.

Each pit lane has a PIT sign before the entry (`track/pit_sign` template), "PIT"
lettering, white limiter lines and a framed service box. On The Raceway, the pit
building stands beside the box. The setup screen's circuit preview draws both lanes
and the box from the real geometry.

## Pit service (`PitWorld`, host-authoritative)

- Stopping in the service box (below 12 px/s) for **6 s** restores **+30 condition
  points**, never above 100 %. The service is free.
- Moving off or leaving the box interrupts the service and restores nothing.
- Each pit-lane traversal allows one service. Nudging out of the box and back in
  does not repeat it; the next service needs another lap.
- No ammunition is restored. A retired (DNF) car is never repaired.
- **Knockout:** no service (pit lanes still exist; driving through gains nothing).
- **Battle Royale:** no pits; the Scrapyard arena has none.
- **HUD:** while servicing, the pit line shows "PIT SERVICE - REPAIRING" and
  "CONDITION: 42% -> 72%", with a progress bar.

## Pit limiter

- **Engages** when a car enters the pit lane proper, beside the divider.
- **Caps the car at 50 %** of its top speed (`CarModel.speed_cap`). The slow-down is
  smooth, at 0.6 × brake deceleration, never a teleport.
- **Releases** when the car leaves the lane. The car then accelerates normally; there
  is no boost.
- **Never on the racing road:** a test samples every 20 px of all three circuits.
- **HUD:** "PIT LIMITER - 50%", with the configured accelerator binding and the
  price of overriding it.

## Override and speeding ticket

- **Override:** double-tap the configured **Fire / accelerate** binding (keyboard or
  controller) inside the pit lane, with both presses within 0.35 s.
  - A press held through the entry never counts; it must be released first.
  - The override lasts until the end of that traversal. The next entry engages the
    limiter again.
- **Ticket:** one ticket per traversal, however many taps follow.
  - **Garage races (the human):** a $150 fine, deducted at settlement and shown on the
    results and the garage. Money never goes below $0.
  - **Every other mode, and every rival:** a 3 s sporting penalty, held at the
    limiter speed just after the lane.
- **Banner:** "PIT LANE VIOLATION! SPEEDING TICKET ..." once per ticket.
- **Kill feed:** an entry `NAME [ticket icon] PIT SPEEDING` (`ui/ticket` template).
  It has no victim and does not change K, D or the tombstone count.
- **Announcer:** the user's recording "Pit lane violation" (`voice/announcer_pit_violation`).
  - It goes through the Voice Director: one speaker at a time, its own short memory,
    and at most one line per ticket.
  - It can be overridden at `custom/audio/voice/announcer_pit_violation.*`.
  - The game works without it.

## AI

- **Same limiter:** rivals obey it like the player, and the same tickets and penalties
  apply to them.
- **Rare overrides:** a few rivals override deliberately (`pit_speeding`):
  - Rocco 0.35, Dante 0.15, Finn 0.1, Nina 0.03, Maya 0.05, Victor 0.002, Greta never;
  - the chance is three times higher in a late podium fight.
- **Pit strategy:** before the entry a rival weighs:
  - condition against its `pit_threshold`, raised for long races;
  - laps to go (no stop on the last lap);
  - its `pit_stay_out_chance` when the DNF risk is low.

  It then drives the pit route at the limiter, brakes into the box, waits out the
  service and merges back. A missed entry abandons the stop rather than grinding along
  the divider.
- **Split sections:** before each fork, a rival picks a lane from:
  - the route time at the line's speeds;
  - traffic in each lane (`route_traffic_weight`);
  - temperament (`route_whim`): Finn is the least predictable, Victor and Greta the
    most consistent;
  - Rocco takes the lane of a rival he is chasing.

## Weapons and the divider

Missiles explode on dividers (`CombatWorld.branch_layout`), as on barriers. Mines
stay where they were dropped.

## Network (protocol 6)

- **Pit state:** every snapshot carries each car's packed pit state: limiter,
  overridden, penalty and service progress.
- **Client's own car:** follows the host's limiter.
- **Override:** a client's double tap travels as a running total in INPUT, so it is
  delivered exactly once. The host grants it, issues the ticket and does all repairs.
- **Ticket events:** they reach the client's kill feed and announcer through the
  reliable EVENTS channel.

## Vehicle lights at night (`LightingPilot`)

- **Headlights and taillights:** every car has two headlight beams and two red
  taillights. This includes junkers and won cars in their original colours.
- **Brake lights:** brighter while the car slows hard (more than 110 px/s²). This is
  measured from the car's movement, so it also works for a network client's cars.
- **Automatic high beams:**
  - **On:** above 55 % of top speed, with no car within 560 px in the beam and the road
    straight for 520 px ahead.
  - **Dip:** for traffic or a bend. Blending takes about 0.3 s, and the state is checked
    ten times a second per car.
- **Settings → DYNAMIC VEHICLE LIGHTS:**
  - Saved in `user://settings.cfg` as `[video] dynamic_vehicle_lights`.
  - **On:** real 2D lights, one twin-beam headlight light and one twin-lamp tail light
    per car.
  - **Off:** a cheap fallback with additive glow sprites and no light passes.
  - In both modes, the lamp lenses are small additive sprites.
- **Environments:** Wasteland Night is darker so the headlights carry through the
  rain; Winter Night is blue moonlight with warm lamps and snow crossing the beams.
- **No effect on the race:** lighting is presentation only. A race is bit-identical
  with lighting on or off (`test_lighting_pilot.gd`).

## Measurements (2026-11-17, before = fc5e1f7, after = this update)

### AI simulations

Ten-rival spectator races, Green Valley, seed 811, one race per cell. Columns:
- race time (s);
- DNFs;
- mean condition of the finishers;
- barrier contacts;
- car contacts;
- after only: pit stops / planned stops, tickets, and split-lane use (left : right
  lane passes).

| Circuit | Laps | Armed | Before | After | Stops, tickets, splits |
|---|---|---|---|---|---|
| Kestrel Ridge | 3 | no | 108 s, 0, 98 %, 33, 271 | 109 s, 0, 97 %, 36, 265 | 0, 0, 9 : 18 |
| Kestrel Ridge | 3 | yes | 129 s, 1, 53 %, 91, 251 | 129 s, 1, 44 %, 60, 161 | 0 / 1, 0, 15 : 17 |
| Kestrel Ridge | 7 | no | 244 s, 0, 98 %, 76, 293 | 245 s, 0, 97 %, 81, 290 | 0, 0, 33 : 30 |
| Kestrel Ridge | 7 | yes | 263 s, 4, 39 %, 98, 224 | 288 s, 1, 53 %, 117, 175 | 7 / 8, 0, 35 : 29 |
| Kestrel Ridge | 20 | no | 687 s, 0, 98 %, 189, 344 | 688 s, 0, 97 %, 220, 340 | 0, 0, 96 : 87 |
| Kestrel Ridge | 20 | yes | 699 s, 4, 61 %, 220, 274 | 745 s, 4, 57 %, 202, 441 | 6 / 11, 2, 51 : 64 |
| Kestrel Ridge | 50 | no | 1708 s, 0, 94 %, 486, 398 | 1714 s, 0, 96 %, 531, 378 | 0, 0, 242 : 211 |
| Kestrel Ridge | 50 | yes | 1724 s, 5, 46 %, 569, 206 | 1770 s, 4, 59 %, 574, 469 | 26 / 29, 5, 131 : 135 |
| Larkspur Ring | 3 | no | 103 s, 0, 100 %, 25, 93 | 103 s, 0, 100 %, 24, 86 | 0, 0, 11 : 16 |
| Larkspur Ring | 3 | yes | 119 s, 0, 56 %, 58, 119 | 135 s, 0, 50 %, 54, 144 | 2 / 3, 2, 16 : 17 |
| Larkspur Ring | 7 | no | 234 s, 0, 100 %, 50, 101 | 234 s, 0, 100 %, 53, 95 | 0, 0, 33 : 30 |
| Larkspur Ring | 7 | yes | 255 s, 4, 55 %, 100, 304 | 286 s, 2, 56 %, 112, 215 | 5 / 6, 2, 32 : 32 |
| Larkspur Ring | 20 | no | 658 s, 0, 99 %, 137, 154 | 658 s, 0, 98 %, 144, 118 | 0, 0, 94 : 87 |
| Larkspur Ring | 20 | yes | 683 s, 4, 37 %, 162, 336 | 734 s, 4, 55 %, 108, 275 | 13 / 20, 2, 55 : 68 |
| Larkspur Ring | 50 | no | 1635 s, 0, 99 %, 341, 183 | 1637 s, 0, 96 %, 350, 161 | 0, 0, 230 : 223 |
| Larkspur Ring | 50 | yes | 1645 s, 5, 63 %, 290, 213 | 1749 s, 6, 53 %, 254, 252 | 19 / 29, 4, 105 : 103 |
| Ravenhook | 3 | no | 115 s, 0, 99 %, 27, 134 | 115 s, 0, 98 %, 39, 100 | 0, 0, 15 : 12 |
| Ravenhook | 3 | yes | 143 s, 3, 33 %, 104, 211 | 142 s, 0, 48 %, 66, 226 | 2 / 2, 0, 19 : 12 |
| Ravenhook | 7 | no | 262 s, 0, 99 %, 68, 143 | 263 s, 0, 97 %, 92, 109 | 0, 0, 34 : 29 |
| Ravenhook | 7 | yes | 282 s, 3, 38 %, 104, 208 | 285 s, 5, 59 %, 59, 110 | 2 / 5, 1, 24 : 13 |
| Ravenhook | 20 | no | 742 s, 0, 99 %, 201, 243 | 740 s, 0, 96 %, 246, 168 | 0, 0, 118 : 64 |
| Ravenhook | 20 | yes | 759 s, 5, 33 %, 203, 157 | 806 s, 6, 54 %, 190, 197 | 5 / 10, 1, 40 : 30 |
| Ravenhook | 50 | no | 1850 s, 0, 93 %, 506, 1195 | 1845 s, 0, 90 %, 558, 828 | 0, 0, 288 : 165 |
| Ravenhook | 50 | yes | 1851 s, 7, 33 %, 225, 358 | 1881 s, 7, 48 %, 201, 305 | 8 / 20, 2, 79 : 56 |

**Reading the table:**
- **Unarmed races** are essentially unchanged: race time within 0.5 %.
- **Armed races** run 0–7 % longer because of pit stops. Finishers end with more
  condition (e.g. Larkspur 20 laps, 37 → 55 %). DNFs vary race to race and show no
  systematic change (one seed per cell).
- **Pit stops:** rivals pit only when damaged. Planned stops that were not made are
  mostly aborted entries (a car shoved wide before the divider) or cars that retired
  first.
- **Tickets:** 0–5 per race, mostly Rocco.
- **Lanes:** both split lanes are used on every circuit. Ravenhook's wide left lane is
  preferred, about 1.5–2 : 1.
- **Stuck rivals found and fixed:** the first run of this table found rivals pinned on
  the pit divider (6,920 barrier contacts in one armed 50-lap Kestrel race; fixed:
  rivals follow the lane they are in). After the fix, barrier contacts are back to the
  "before" level.

### Performance

Night, spectating, software OpenGL (llvmpipe, no GPU), measured while other jobs
were running, so the figures are relative only:

| Version | Day | Night |
|---|---|---|
| Before (single glow per car) | 39.0 fps | 24.5 fps |
| After, DYNAMIC VEHICLE LIGHTS on | 35.8 fps | 19.6–21.2 fps |
| After, DYNAMIC VEHICLE LIGHTS off | — | 26.1 fps |

The fallback is cheaper than the old single glow.
