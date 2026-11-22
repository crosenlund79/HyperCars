# HyperCars — completion readiness

**As of:** 2026-11-22, after the Stabilization & Pre-Completion Pass.
**Branch:** `claude/festive-hypatia-15k6fj`.
**Backup:** branch `backup-20261122-pre-stabilization` at `630f25a`. A branch rather
than a tag: this session's git access refuses tag pushes, and the user chose a backup
branch.

This document records what stands between the current build and a finished game. It
is not a plan and approves nothing (`docs/GODOT_CLAUDE_GUIDELINES.md`, rule 7).

## Where the game stands

Every mode works end to end in automated runs:
- Quick Race, Garage Race (saved career), Championship (with car ownership and Racing
  for Keeps), Knockout, Battle Royale and Spectate;
- couch split-screen;
- LAN / online with a host and a client.

These systems are complete and tested in code:
- three circuits, five environments, day / night;
- combat, damage and pit lanes;
- remappable controls;
- music, voice and achievements;
- the artwork override pipeline.

What has not happened is a structured human playtest on real hardware. Balance and
feel are therefore unproven, not wrong.

### Can the existing modes make a complete, enjoyable game?

**Probably yes, structurally.** A player can:
- race single races;
- run a saved garage career with money, weapons, repairs and armour;
- win championships to collect all nine rival cars, which is a finite goal with an
  ending;
- play couch or online.

That is a complete loop **without new modes or circuits**. Whether it is *enjoyable*
for long enough is exactly what the playtest (B) must answer.

**The long-term career structure is still a design question** (see D1). It is not
permission to implement one.

## A. Confirmed bugs (still open)

None of these block a normal session.

| # | Defect | Effect | Notes |
|---|---|---|---|
| A1 | Two cars on the same branch can pass through each other for a few frames exactly at an elevation-zone end (J1 design limit). | A rare visual pass-through on bridge circuits. | Known since J0–J2. A fix would touch collision layering. |
| A2 | Network clients see collision retirements without the culprit in the kill feed: the host's attribution is not sent. | Kill-feed text on the client only. Results, DNFs and K / D deaths agree. | A small protocol addition if wanted. |
| A3 | A client's car bumps arrive as host corrections: they look slightly late or snappy, with a handful of hard snaps per race at 80–120 ms. | Feel only, online. | The prediction design (M5.2). Needs real two-PC play to judge. |
| A4 | Test only: two `test_net_lan_race` cases fail intermittently under full-suite load. "Armed jump race at 170 ms" can hit its 140 s wall-clock limit while rivals are still racing. "Experimental crossing armed race" once compared unequal: GUT truncated the dictionaries, so the field is unknown. Hypothesis, unconfirmed: the client's observed take-off count on the figure-eight's test jump. | No game effect found: order, times, DNFs, condition, ammunition and destructions come from reliable messages. | 2026-11-22: each failed once in the full suite. Both pass re-run alone (2 / 2 and 3 / 3, also with every core saturated). The crossing test now compares key by key, so the next failure names the field. |

## B. Human playtesting (only real play can verify these)

Automated tests do not prove any of the following:

- **Real controllers:**
  - DualSense and Xbox pads on Windows / Linux;
  - hot-plugging;
  - couch with two pads;
  - remapping with a pad.
- **Two-computer networking:**
  - real LAN and internet play;
  - port forwarding;
  - real latency and loss;
  - disconnects.

  Everything so far ran on one machine with simulated latency.
- **Performance on a real GPU:** only software rendering has been measured. Night with
  dynamic lights, split-screen and 50-lap armed races are the heaviest cases.
- **Audio by ear:**
  - music loops and crossfades;
  - the Battle Royale loop;
  - engine layers;
  - the voice speed-up;
  - ducking.
- **Balance and feel:**
  - combat deadliness;
  - DNFs in long armed races;
  - Rocco's win rate;
  - garage prices and prizes;
  - pit rules (+30, 6 s, 50 % limiter);
  - pit-ticket blame;
  - Battle Royale timing;
  - Nemesis Welcome frequency and wording.
- **Readability at 1080p and on a TV:** HUD, standings, couch views and the night
  lighting.
- **This pass's visible fixes:**
  - the high beam now starts at the headlights;
  - the title backdrop shows the chosen won car;
  - pit tickets appear in the offending player's couch view;
  - achievement toasts wait for the championship standings to close.
- **Custom artwork:**
  - the user's own drawings in `custom/` (nose to the right, see
    `docs/ARTWORK_MASTER_LIST.md`);
  - an exported Windows / Linux build reading `custom/` next to the executable. This
    path has never been exercised: no export has been made.

The consolidated checklist is `tests/manual/playtest_checklist.md`.

## C. Essential missing functionality

Only things an approved system needs to work as intended:

- **C1. Export presets and one real export per target** (Windows / Linux), once the
  user approves builds (guideline 4). Without one, the runtime `custom/` override
  contract (guideline 3) is untested where it matters most.
- **C2. Target platforms** are still "Undecided" in the brief. C1 depends on this.

Nothing else was found. Every approved mode and system is implemented.

## D. Design decisions (for the user and ChatGPT; not approved)

- **D1. Long-term structure:** a career or season framework (tiers, levels like the
  original's 3 × 7 tracks, progression). Today: the garage career plus championships
  and car collection.
- **D2. Super Cars II items not implemented:**
  - upgrades: turbo / jump, battering ram, engines;
  - track hazards: trains, gates;
  - the interview characters.

  Add these only by explicit decision.
- **D3. Balance after the playtest:**
  - weapon damage by race length;
  - Rocco ("Mad Dog") winning about 31 % of armed races;
  - consolation money for P6+ in garage races;
  - garage prize multipliers for 20 / 50 laps (extrapolated).
- **D4. Network scope:**
  - reconnect;
  - NAT traversal / relay;
  - more players;
  - online Knockout / Battle Royale.
- **D5. AI scope:**
  - rivals caring about their own condition;
  - rival armour;
  - AI awareness of mines.

## E. Optional improvements (not needed to finish)

- **Artwork:** the user's own drawings replacing the templates one at a time, the
  planned next phase. Optional new catalogued pictures for visuals still drawn in
  code: arena floor and blocks, divider tops, jump ramps, pit lettering.
- **Audio:**
  - voice recordings for more rivals and events: overtakes, finishes, the Nemesis
    greetings (`docs/NEMESIS_WELCOME.md`);
  - per-file loop points for MP3 overrides.
- **Presentation:**
  - per-board ad and crowd variety;
  - a pit line for the followed rival in spectator mode;
  - Artwork Mode applying without a restart.
- **Robustness:** atomic save writes (write to a temporary file, then rename). A crash
  during a save could today leave a broken file, which loads as a fresh career. Never
  observed; a theoretical risk.

## Fixed in this pass (2026-11-22)

| Fix | Root cause | Test |
|---|---|---|
| Night high beam lit the road behind the car ("headlights from the wrong end") | Godot scales a `PointLight2D` texture about its centre without scaling `offset`; the high beam (×1.45) slid ~58 px back, starting behind the car's centre. The offset now grows with the beam. Lamp anchors made explicit and body-relative. | `test_vehicle_lights.gd`; renders `docs/artwork/night_lights_before_after.jpg` |
| Client could miss a DNF / final condition / ammunition at the flag under packet loss | RESULTS carried only order and times; the rest came from the last unreliable snapshot. RESULTS now carry final DNF, condition and ammunition (protocol 7). | `test_net_authority.gd` (every snapshot dropped), `test_net_lan_race.gd` |
| Title backdrop showed the own car when a won car was chosen | The backdrop always parked `car_player`. It now parks the chosen car (CarArt, original colours) and updates on change. | `test_title_backdrop.gd`; render `docs/artwork/title_backdrop_won_car.jpg` |
| Couch pit-ticket banner on the shared screen | The ticket used the shared HUD banner. It now shows in the offender's own view, between its info panel and its car. | `test_stabilization_ui.gd`; render `docs/artwork/couch_pit_ticket_view.jpg` |
| Achievement toasts over the championship standings | The toast's place (top right) is inside the standings layout. Toasts now wait while the standings are up; one on screen leaves and returns later. | `test_stabilization_ui.gd` |
