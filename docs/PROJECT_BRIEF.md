# Project Brief — Single design and task handoff record

This is the **master template**, not an active game. Complete it collaboratively when creating a game. This file **records** decisions and approvals; it never grants them. Only the user can approve scope, in their message in the current conversation. **Undecided = ask, don't choose.**

## Game decisions (user-confirmed only)

- **Game title:** Undecided
- **Godot version (pin minor, e.g. 4.x):** Undecided
- **Premise / core player loop:** Undecided
- **Perspective / art direction:** **Approved 2026-11-14 (user, "HyperCars — Approved Visual Direction").** Top-down view. Original, modern, hand-painted HyperCars identity; do **not** reproduce the original Super Cars II pixel art.
  - **Style reference:** the user's own *Fluffy Bears of Doom* drawings in `docs/art_refrence/` (folder name as committed): `bomb`, `chair`, `clown`, `duck`, `effects`, `fluff`, `powerups`, `tiles` (`.png`).
  - **Study only their artistic characteristics:** hand-painted textures, soft brushwork and organic outlines; slightly imperfect, asymmetrical shapes with personality; soft shading, highlights and subtle surface texture; their colour choices, proportions and playful character. **Never recreate or incorporate the depicted objects** (bomb, furniture, bear, chest, clown, duck, etc.).
  - **Applies to** original HyperCars artwork: top-down cars, tracks, terrain, obstacles, weapons, interface elements and other assets as required.
  - **Asset rules:** `template_` graphics must be proper, visually appealing art, not programmer placeholders; all assets stay stylistically consistent so the user's drawings can replace them one at a time; user artwork has priority and missing custom assets fall back to Claude's templates through the existing `custom/` override contract (`assets/README.md`), including replacement in exported Windows/Linux games without rebuilding; consistent dimensions, transparency, alignment and animation/sprite-sheet layouts must be defined; create only assets needed for approved iterations.
- **Confirmed mechanics and constraints:** Gameplay remains mechanically faithful to Super Cars II (1991, Amiga); graphics follow the approved visual direction above (user, 2026-11-14). Detailed mechanics are not yet confirmed.
- **Explicitly out of scope:** Undecided
- **Existing modules / boundaries:** None; no game code in starter pack
- **Testing framework (GUT or GdUnit4) and commands:** Undecided until first implemented module
- **Target platforms:** Undecided (runtime asset overrides currently cover Windows/Linux only; other platforms need an explicit decision)
- **Asset override notes:** Runtime `custom/` folder overrides required; see `assets/README.md`

## Current approved development objective

**Status: None.** This heading records an objective *after* the user approves it in conversation; it is not an instruction to implement, and a later task needs fresh approval.

- **User approval (reference / summary):** None
- **Objective (one by default):** None
- **In scope:** None
- **Out of scope:** None
- **Acceptance criteria / done when:** None
- **Relevant module tests:** None
- **Relevant integration/manual checks:** None

## Proposals awaiting user approval

Keep proposals clearly separate from confirmed decisions and active work. Do not promote them to tasks automatically.

- **Asset dimension and sprite-sheet conventions (Claude proposal, not approved).** Observed in `docs/art_refrence/`: RGBA PNGs with transparent backgrounds; most sheets are horizontal strips of 256×256 cells (e.g. `tiles` 9 cells, `powerups` 10, `effects` 8); exceptions `chair` 384×384 and `fluff` 128×128. Proposed baseline: 256×256 source cells in horizontal strips, transparent background, objects centred in the cell, terrain tiles edge-to-edge. Open: in-game scale versus internal resolution, car rotation (pre-painted frames versus runtime rotation; the original's rotation-step count is unverified), pivot/anchor points, and frame-layout rules for overrides.
