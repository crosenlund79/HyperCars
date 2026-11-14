# Project Brief — Single design and task handoff record

This is the **master template**, not an active game. Complete it collaboratively when creating a game. This file **records** decisions and approvals; it never grants them. Only the user can approve scope, in their message in the current conversation. **Undecided = ask, don't choose.**

## Game decisions (user-confirmed only)

- **Game title:** HyperCars (user)
- **Godot version (pin minor, e.g. 4.x):** 4.7.x — developed and tested with 4.7.2-stable, GL Compatibility renderer (user, 2026-11-14)
- **Premise / core player loop:** Undecided
- **Perspective / art direction:** **Approved 2026-11-14 (user, "HyperCars — Approved Visual Direction").** Top-down view. Original, modern, hand-painted HyperCars identity; do **not** reproduce the original Super Cars II pixel art.
  - **Style reference:** the user's own *Fluffy Bears of Doom* drawings in `docs/art_refrence/` (folder name as committed): `bomb`, `chair`, `clown`, `duck`, `effects`, `fluff`, `powerups`, `tiles` (`.png`).
  - **Study only their artistic characteristics:** hand-painted textures, soft brushwork and organic outlines; slightly imperfect, asymmetrical shapes with personality; soft shading, highlights and subtle surface texture; their colour choices, proportions and playful character. **Never recreate or incorporate the depicted objects** (bomb, furniture, bear, chest, clown, duck, etc.).
  - **Applies to** original HyperCars artwork: top-down cars, tracks, terrain, obstacles, weapons, interface elements and other assets as required.
  - **Asset rules:** `template_` graphics must be proper, visually appealing art, not programmer placeholders; all assets stay stylistically consistent so the user's drawings can replace them one at a time; user artwork has priority and missing custom assets fall back to Claude's templates through the existing `custom/` override contract (`assets/README.md`), including replacement in exported Windows/Linux games without rebuilding; consistent dimensions, transparency, alignment and animation/sprite-sheet layouts must be defined; create only assets needed for approved iterations.
- **Confirmed mechanics and constraints:** Gameplay remains mechanically faithful to Super Cars II (1991, Amiga); graphics follow the approved visual direction above (user, 2026-11-14). Controls as confirmed by the user from the original manual (2026-11-14): joystick left/right steer; two control modes — *Fire to Accelerate* (fire held accelerates, releasing fire brakes automatically) and *Fire to Brake* (automatic acceleration, fire held applies stronger braking); joystick up/down fire front/rear weapons, never brake. All physics values are provisional until calibrated against the original. **M1 handling is the approved baseline** (user, 2026-11-14, M1.1+M2 brief): any change to driving physics needs user approval. Original race rule reported by the manual and applied where relevant: the finishing order reverses the next race's grid (winner starts last).
- **Explicitly out of scope:** Undecided
- **Existing modules / boundaries (M1, M1.1, M2):**
  - `src/driving/` — `CarModel` (pure deterministic driving model; symmetric car-to-car contact), `DrivingParams` (provisional tunables, `default_driving_params.tres`), `Car` scene (physics body, wall and car contacts).
  - `src/track/` — `TrackLayout` (straights + per-corner radii, starting grid; `circuit_01.tres`), `ClosedPath` (arc length/projection), `Track` (builds ground, road, barriers, start line, checkpoint gates, grid slots; emits `checkpoint_reached`).
  - `src/race/` — `LapTracker` (in-order checkpoint laps), `RacerState`, `RaceSession` (mode select → racing → finished; field standings, finishing order, reversed grid), `RaceProgress` (continuous distance for live positions).
  - `src/ai/` — `RacingLine` (line + speed profile from shared driving params), `AiDriver` (player-equivalent inputs: digital steer + fire), `AiParams` (provisional, `default_ai_params.tres`).
  - `src/controls/` — `PlayerControls` (input actions, digital joystick reading). `src/camera/` — `FollowCamera`. `src/ui/` — `Hud`.
  - `src/assets/` — `AssetResolver` (override/fallback), `AssetCatalog` (replacement contract). `src/main/` — composition root; no Autoloads.
- **Testing framework (GUT or GdUnit4) and commands:** GUT 9.7.1 (vendored in `addons/gut/`; user, 2026-11-14). Run all tests headless from the project root: `godot --headless --path . --import` once, then `godot --headless --path . --fixed-fps 60 -s addons/gut/gut_cmdln.gd` (config: `.gutconfig.json`; engine errors and `push_error` fail tests; `--fixed-fps 60` simulates the AI races in ~3 s instead of ~1 min in real time — both pass). Manual checklists: `tests/manual/m1_driving_checklist.md`, `tests/manual/m2_racing_checklist.md`.
- **Target platforms:** Undecided (runtime asset overrides currently cover Windows/Linux only; other platforms need an explicit decision)
- **Asset override notes:** Runtime `custom/` folder overrides required; see `assets/README.md`. Per-asset replacement contract lives in `src/assets/asset_catalog.gd`: overrides are PNG, may be any resolution but must keep the template's aspect ratio and orientation; the game scales them to a fixed display size. M1 assets (template px → display): `cars/car_player` 128×72 → 64×36 (nose right, centred, transparent); `track/tarmac`, `track/grass` 256×256 seamless, one tile = 256 world px; `track/wall` 128×32 strip seamless left-right, 20 px wide; `track/start_line` 32×128, stretched across the road; `ui/hud_panel` 96×96 nine-patch, 24 px margins. M2 adds `cars/car_ai_1` … `cars/car_ai_9`, same contract as the player car. `docs/.gdignore` keeps the art references out of Godot imports.

## Current approved development objective

**Status: Delivered for user playtesting (awaiting approval).** This heading records an objective *after* the user approves it in conversation; it is not an instruction to implement, and a later task needs fresh approval.

- **User approval (reference / summary):** User, 2026-11-14, "HyperCars — M1.1 + M2: Real Racing" (two bundled objectives). Previous: M1 Driving Prototype (delivered; its handling is the approved baseline).
- **Objective:** M1.1 — redesign the test circuit (straights, long sweepers, distinct tight bends) keeping M1 physics, collisions, checkpoints and laps. M2 — AI opponents with the player's physics: racing lines, cornering, overtaking, car-to-car collisions, live positions, finishing order, results; up to the original 10-car field.
- **In scope:** As above, original starting-grid rule where applicable, hand-painted `template_` opponent cars with overrides, modular tests and manual checklist.
- **Out of scope:** Driving-physics retuning, rubber-banding or AI advantages, weapons, damage, shop, championship, multiplayer, additional tracks, unrelated features, exports, framework changes.
- **Acceptance criteria / done when:** M1.1 tested before M2; full 10-car race playable; lap counting, positions, collisions, AI navigation and race completion tested; all existing tests still pass; user playtests and approves.
- **Relevant module tests:** `tests/unit/` (+ closed path, race progress, racing line, AI driver, race standings).
- **Relevant integration/manual checks:** `tests/integration/` (+ car↔car physics, AI race with 1 / 3 / 9 opponents, results and reversed grid); `tests/manual/m2_racing_checklist.md`; exported-build override check pending (no export approved).

## Proposals awaiting user approval

Keep proposals clearly separate from confirmed decisions and active work. Do not promote them to tasks automatically.

- **Asset dimension and sprite-sheet conventions (Claude proposal — universal 256×256 format not adopted, user 2026-11-14; dimensions are chosen per asset).** Observed in `docs/art_refrence/`: RGBA PNGs with transparent backgrounds; most sheets are horizontal strips of 256×256 cells (e.g. `tiles` 9 cells, `powerups` 10, `effects` 8); exceptions `chair` 384×384 and `fluff` 128×128. Proposed baseline: 256×256 source cells in horizontal strips, transparent background, objects centred in the cell, terrain tiles edge-to-edge. Open: in-game scale versus internal resolution, car rotation (pre-painted frames versus runtime rotation; the original's rotation-step count is unverified), pivot/anchor points, and frame-layout rules for overrides.
