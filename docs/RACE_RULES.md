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

## Fingerprints

With `damage=0 lock=0 contact=0` (`sim_probe.gd`) the original eight fingerprints are
unchanged; with `lock=0 contact=0` the M6 ones. With everything on, the current values
are pinned in `tests/integration/test_multiplayer_regression.gd` (the start is calmer and
contacts turn cars, so races differ on purpose). No Guns races also change (contact yaw).
