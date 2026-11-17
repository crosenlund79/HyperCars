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
