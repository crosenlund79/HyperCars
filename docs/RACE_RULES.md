# Race rules added after M6

## Weapons Hot (start lock)

In every race with weapons, nobody can fire until the whole starting field is through
the start line: no shot, no ammunition used, no empty click; rivals do not even decide
on shots (nothing is stockpiled), and presses made during the lock are dropped. The
lock opens once, for everyone at the same tick, when every car still in the race has
crossed the start line for the first time (race distance from below zero to zero or
more; later moves never undo it). Retired (DNF) or finished cars never hold the field;
after 15 s of racing (`Main.weapons_lock_timeout`) it opens anyway, so a car that never
leaves the grid cannot lock everyone's weapons. The HUD shows "WEAPONS LOCKED" until
then, and the announcer says "Weapons hot" at the unlock (a combat "unlock" event).
No Guns races never lock, warn or announce. The host decides in network races (the
lock travels in snapshots, the unlock event with the other combat events; protocol 4).

## Rear-quarter contact

Car-to-car contacts give each car a brief, damped yaw from where it was struck: the
angular impulse (contact offset × impulse, over half the car length squared) ×
`contact_yaw_factor` 0.9. Struck behind its centre, a car gets the full effect (the rear
quarter is easy to rotate); struck at the nose only `contact_front_factor` 0.3 of it;
a square push straight from behind none. The extra rotation is capped at 1.6 rad/s
and fades at 4 /s. Measured on an uncorrected car: a nudge (90 px/s closing) turns it
about 5°, a hard rear-quarter hit (250 px/s) about 17°; a driver steers it back within
a second. Never a scripted spin. All cars have the same mass; the same rules for the
player and the rivals; damage and armour unchanged; walls, steering, throttle, brakes
and grip unchanged (`DrivingParams`, provisional).

## Front-wheel steering (visual only)

The front wheels now turn up to 26° (was 10°) with the same smoothing
(`WheelLayout.max_steer_degrees`); the wheels sit mostly under the body, so the angle
shows on their outer edges. The driving model is untouched.

## Race-long ammunition

Every car's starting rounds are multiplied by the race length
(`WeaponRules.ammo_scale_by_laps`: 3 laps x1, 7 x2, 20 x5, 50 x10, capped at 99 per
weapon), for the player's quick / championship loadout, Classic and Tactical rival
loadouts alike. Garage races are the exception: the player carries what they bought
(the economy is unchanged). Rivals pace their ammunition (`AiParams.ammo_discipline`):
a driver who has spent more than their share of the race so far waits for better
shots, one well under budget gets keener, and everyone loosens up on the last lap, so
combat continues to the flag. Rocco (0.15) and Dante (0.35) spend freely; Victor and
Greta (0.9) and Nina (0.85) are calculated.

## Rival racecraft (AI only; same physics for everyone)

- **Own lines**: each rival drives the shared racing line with a personal offset and a
  slow sine "wander" (`line_offset`, `line_wander`, `line_wander_period`): Greta 0, Nina
  4, Maya 5, Hank 6, Ellie 8, Rocco 14, Dante 16, Finn 26 px (Finn unpredictable). Rocco
  also defends harder (`defend_distance` 110, `defend_strength` 0.5); Victor, Greta and
  Nina rarely overcommit. No catch-up, no scripted results.
- **Wreck awareness**: a rival notices a wrecked car ahead after `hazard_reaction`
  seconds within `hazard_lookahead` (Victor 0.15 s / far, Nina 0.08 s, Rocco 0.45 s /
  short) and picks a side to pass, or lifts. Imperfect on purpose.
- **Wreck pass-through**: a car held up (< 90 px/s) within 72 px of a *wrecked* car for
  0.5 s may drive through that one wreck (a collision exception between the two only),
  removed once the wreck is back in the race and they are apart. Active cars always
  collide; retired (DNF) cars already have no collisions and leave the road.
- **Micro Nemesis**: a rival destroyed by someone (rival or human) holds a short grudge:
  for `grudge_time` seconds that car's shots look `grudge_bonus` better to them
  (Rocco 0.3 for 30 s, Nina 0.2 for 25 s, Greta 0.04 for 10 s). Targeting only; it
  fades, and nobody leaves the racing line to chase.

## Environments

The ENVIRONMENT option (renamed from BIOME on 2026-11-17, and from TRACK before that).
Internal ids and the `custom/graphics/variant_N/...` overrides are unchanged. Every
environment runs on every circuit, independent of the layout and of Day / Night.
Each changes handling a little, the same for every car, human or AI:
`TrackTheme.driving()` scales the shared `DrivingParams`.

| Environment | Top speed | Grip | Accel. | Turning | Braking | Weather / look |
|---|---|---|---|---|---|---|
| Green Valley (variant 1) | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | none |
| Wasteland (variant 2) | 1.00 | 0.88 | 0.93 | 0.94 | 0.94 | rain, wet road tint |
| Winter (variant 3) | 1.00 | 0.74 | 0.96 | 1.00 | 0.80 | snowfall |
| The Raceway (variant 4) | **1.05** | **1.05** | 1.00 | 1.00 | 1.00 | professional circuit: kerbs, ad boards, pits, floodlights |
| Tabletop Mayhem (variant 5) | 1.00 | 1.00 | **1.28** | 1.00 | 1.00 | toy cars on a desk among giant everyday objects |

**The Raceway** has striped grass, clean asphalt, a red / white barrier and kerbs on
every corner. Along the circuit are floodlight masts, original generic advertising
boards facing the road, marshal posts and a pit building on the main straight.
At night it is cool floodlit white with 16 lamps.

**Tabletop Mayhem** has a wooden desk, a toy-track road and a ruler barrier. Around it
are giant pencils, playing cards, paperclips, a mug, dice and toy blocks, and there are
no grandstands. At night the light is a warm desk lamp.

Every big prop keeps its whole footprint off every road (tested on all circuits), so
nothing hides the road or looks like a barrier. The geometry and collisions are the
circuit's own.

**Measured** (3 laps, nine rivals):
- No Guns lap times are about 3 % faster on The Raceway and 1–2 % faster on Tabletop
  Mayhem than on Green Valley, and about 4 % slower on Winter.
- Every rival finishes in every environment without weapons.
- With weapons, barrier and contact damage is about 35–45 % higher on The Raceway and
  Tabletop, because cars hit at higher speeds and respawned cars re-accelerate into
  traffic. Retirements went from about 1 in 9 races to 1–2 per race there.
- AI driving needs no environment-specific tuning: racing lines and speed profiles come
  from the scaled parameters. Weather is a light particle layer (`src/presentation/weather_view.gd`) that never
hides the cars. Values provisional in `src/track/themes/variant_N.tres`.

## Day / Night

TIME: DAY / NIGHT is a setup option, independent of environment and circuit, also used by the
championship schedule. Night promotes the lighting pilot: an environment-specific moonlight
tint (`night_ambient`), lamp posts (`lamp_color`, `lamp_energy`) and per-car headlights
(`headlight_energy`); Winter night is blue moonlight with warm lamps and snowfall
crossing the headlights. Night never changes physics. L still toggles lights in any race.

## Fingerprints

All pinned simulation fingerprints were re-recorded with the race-experience update
(2026-11-16): the rivals' own racing lines, wreck awareness, ammo pacing and
race-length ammunition change every AI race, so no earlier value can hold. The three
sets in `tests/integration/test_multiplayer_regression.gd` keep their meaning
(`damage=0 lock=0 contact=0`, `lock=0 contact=0`, everything on), as do the M2.3 /
M3 gates in `test_combat_race.gd` / `test_tactical_race.gd`; old values are in git
history. Biomes change handling, so `test_track_themes.gd` now checks that each
biome differs from Green Valley and is deterministic, instead of identical races.
J6 (same day): rivals ignore retired cars (and cars down in a jump's gap) as traffic
and targets; races in which a car retires change, so the two damage-on sets were
re-recorded again (the damage-off set and the No Guns all-on value are unchanged).
Day / Night, the menus, the championship screens, rewards and the popup are
presentation or flow only and do not change a race.
