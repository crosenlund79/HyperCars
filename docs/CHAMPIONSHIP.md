# Championship, car rewards and the race setup screen

## GO RACING! and the race setup screen

The title's main menu is GO RACING! / ACHIEVEMENTS / SETTINGS / CONTROLS / QUIT.
GO RACING! lists QUICK RACE, GARAGE RACE, CHAMPIONSHIP, SPECTATE and MULTIPLAYER.
Every entry opens the same setup screen (`src/ui/title_screen.gd`):

| Row | Values | Shown for |
|---|---|---|
| CIRCUIT | Kestrel Ridge / Larkspur Ring / Ravenhook | all but Championship |
| BIOME | Green Valley / Wasteland / Winter | all but Championship |
| TIME | DAY / NIGHT | all but Championship |
| LAPS | 3 / 7 / 20 / 50 | all but Championship |
| WEAPONS | ON / NO GUNS | all |
| COMBAT | Classic / Tactical | all |
| CONTROL | Fire to Accelerate / Fire to Brake | all but Spectate |
| CAR | your own car or a won rival car | Quick, Garage, Championship |

Enter (or Left / Right) changes a row; START begins; Esc goes back. Circuit, biome,
time, laps, weapons, style, control and car are saved in `user://settings.cfg`.
MULTIPLAYER continues to SPLIT SCREEN (press-a-button join) and LAN / ONLINE as before;
a LAN / online client races the host's circuit, biome and time of day (sent in WELCOME).

The right half shows a rotating low-poly diorama of the chosen circuit
(`src/ui/circuit_preview.gd`): a faceted plate in the biome's colours, the real
centreline, bridges lifted on pillars, the jump's gap left open (gold markers), the
start line, a few faceted trees and, at night, warm lamps. It is drawn procedurally
(no 3D scene, no artwork) and rebuilt whenever the circuit, biome or time changes.

## The championship

Three rounds, one on each original circuit, against all nine rivals
(`src/championship/championship.gd`, `championship_schedule.gd`).

- **Schedules** are resources: `hypercars_cup.tres` (Kestrel Ridge, Green Valley, day ->
  Larkspur Ring, Wasteland, night -> Ravenhook, Winter, night) and `night_series.tres`
  (Larkspur Ring, Winter, day -> Ravenhook, Green Valley, night -> Kestrel Ridge,
  Wasteland, day); 3 laps each. Championships take turns through
  `ChampionshipSchedule.SCHEDULES` (the count is saved), so consecutive runs race
  different combinations. Add a schedule by adding a `.tres` and listing it.
- **Points** 25 / 18 / 15 / 12 / 10 / 8 / 6 / 4 / 2 / 1 (per schedule); a DNF scores
  nothing and is classified behind the finishers.
- **Ties**: points, then countback (more wins, then more seconds, ...), then the last
  round's result, then racer id.
- **Grids**: round 1 = rivals in id order, the player last; afterwards the previous
  round's order reversed (the winner starts last), as in normal races.
- **Between rounds** the standings screen (`src/ui/championship_screen.gd`) shows the
  table (position, car, driver, last result, wins, points) and the next round's circuit,
  biome, time of day and laps with the rotating preview; START ROUND n or ABANDON.
- **Racing**: the setup's weapons, combat style, control mode and car apply; the standard
  quick-race loadout (no garage money); ammunition scales with the round's laps; the HUD
  names the round. Esc pauses (RESUME RACE / ABANDON CHAMPIONSHIP); leaving abandons the
  championship (nothing won). Fire on the results continues to the standings.
- **Final**: the final standings and the champion. Rounds count for achievements and
  rival careers like normal races.

## Car rewards (`src/garage/car_collection.gd`)

Winning a championship unlocks one random rival car the player does not own yet and
saves it in `user://car_collection.cfg` (never a duplicate; all nine can be collected).
The reward screen says e.g. "CHAMPIONSHIP WON - YOU UNLOCKED THE HUNTER!" with the car
in the player's red; after the ninth, "ALL NINE RIVAL CARS COLLECTED!", and later wins
say the collection is complete.

- **The player's car**: the setup's CAR row picks the own car or any won car. A won car
  keeps the rival's silhouette and details with its main paint turned red
  (`src/assets/car_paint.gd`: the most common saturated hue -> the player's red, shading
  kept; also for user art). If an image cannot be read or has no clear paint colour,
  it is used as it is (the player marker still shows which car is yours).
- **The displaced rival** races the one shared junker (`cars/body_junker`,
  `cars/car_junker`, slight per-rival tint) from then on, whatever car the player
  picks, with the same name, personality, voice lines and career statistics.
- **Identical performance**: looks only; every car keeps the same driving parameters.
- Applies to single-player races, garage races, championships and spectating; couch
  split-screen and network races keep the standard cars (the other computer has its own
  collection).

## Rival defeat popup (`src/ui/defeat_popup.gd`)

When a rival's weapon destroys a human's car on this computer, a short card shows
that rival's car, full name and one of three lines in their personality
(`src/ai/rival_taunts.gd`), credited to the actual attacker (the combat event's owner).
It is silent, so the Voice Director stays the only voice (announcer and rival lines
never overlap). One card at a time with a 6 s minimum gap, each rival's lines in turn,
nothing for your own weapon, another human's, rival-on-rival hits or spectating.
