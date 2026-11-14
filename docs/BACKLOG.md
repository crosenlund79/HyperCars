# Deferred observations — not approved tasks

Record only observations found during approved work. An item here is **not** permission to implement or add to the current objective.

| Date | Observation | Context |
| --- | --- | --- |
| 2026-11-14 | Fidelity: all `DrivingParams` values (top speed, acceleration, release/brake deceleration, turn rate, grip, wall restitution) are provisional and unmeasured against Super Cars II. | M1 driving prototype |
| 2026-11-14 | Fidelity: unknown whether the original car turns while stationary, uses fixed rotation steps, or reverses; M1 turns at any speed (`full_steer_speed = 0`), rotates smoothly, never reverses. | M1 driving prototype |
| 2026-11-14 | Fidelity: lap count per race (M1 uses 3), road width (150 px) and car/screen scale are provisional. | M1 driving prototype |
| 2026-11-14 | Fidelity: original wall-collision behaviour (bounce, stop, damage) and camera behaviour (rigid vs lag/lead) unverified; M1 uses bounce + scrape and a rigid centred camera. | M1 driving prototype |
| 2026-11-14 | M1 adds a mode-select panel, race timer and lap times as testing/calibration aids; whether the original shows these is unverified. | M1 driving prototype |
| 2026-11-14 | The original manual page (lemonamiga.com) is behind a Cloudflare browser check, so automated sessions cannot read it. | Research access |
| 2026-11-14 | Starter pack: no rule for vendored third-party addons (e.g. `addons/gut/`) — licence, version pinning, exclusion from reviews. | Framework |
| 2026-11-14 | Starter pack: no guidance that non-game folders with images (e.g. `docs/`) need `.gdignore`, or Godot imports them. | Framework |
| 2026-11-14 | Starter pack: asset contract covers single files only; no rule for display size vs resolution, nine-patch margins or seamless tiles (M1 defines these in `src/assets/asset_catalog.gd`). | Framework |
| 2026-11-14 | Starter pack: root `README.md` still describes the starter pack, not HyperCars. | Repository |
| 2026-11-14 | Fidelity (M2): original grid formation (columns, spacing) and the player's grid slot in a first race are unverified; M2 uses two staggered columns and puts the player at the back. Later races use the reversed result (manual rule, as reported). | M2 AI racing |
| 2026-11-14 | Fidelity (M2): whether the original race ends when the player finishes or waits for the field is unverified; M2 shows results when the player finishes, unfinished cars ranked by running order. | M2 AI racing |
| 2026-11-14 | Fidelity (M2): original AI behaviour (line choice, aggression, per-driver or per-difficulty skill, use of contact) is undocumented; all M2 opponents share one provisional `AiParams`, with no catch-up. | M2 AI racing |
| 2026-11-14 | Fidelity (M2): original car-to-car contact response is unverified; M2 uses symmetric equal-mass contact with provisional `car_restitution = 0.4` (new parameter; M1 values unchanged). | M2 AI racing |
| 2026-11-14 | Fidelity (M2): start procedure (countdown/lights) unverified; M2 starts all cars on Fire, as in M1. Lap count (3) still provisional. | M2 AI racing |
| 2026-11-14 | Opening-lap contact is frequent in a full field (about 18 impacts above 60 px/s in a simulated race); acceptable for now, may need tuning once original behaviour is known. | M2 AI racing |
| 2026-11-14 | Placing a physics body in the same frame it is added leaves its old transform on the physics server for one tick (seen in GUT); the game spawns cars frozen on the grid so it is unaffected, tests spawn cars at their position before adding them. | M2 tests |
| 2026-11-14 | Burnt-orange opponent (`car_ai_9`) is close in hue to the red player car; consider a clearer player marker if playtesting finds it confusing. | M2 art |
| 2026-11-14 | Starter pack: `tests/README.md` has no guidance on simulation-time tests (e.g. `--fixed-fps` for deterministic, fast physics runs). | Framework |
