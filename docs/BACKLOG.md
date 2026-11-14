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
