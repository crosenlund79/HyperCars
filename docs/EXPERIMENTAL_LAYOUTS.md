# Experimental track layouts (developer only)

Experimental circuits are **not** in the TRACK menu and never saved. Pick one for a
single run with a command-line argument after `--`:

```
godot --path . -- --layout=exp_figure8_01
```

(With an exported build: `HyperCars.x86_64 -- --layout=exp_figure8_01`.)

Everything else works as usual: the title TRACK button still chooses the visual theme
(Green Valley / Heather Moor / Snow Pass), and RACE, SPECTATE, two players, garage
races and LAN work on the chosen layout. The grid panel says "(EXPERIMENTAL LAYOUT)".
For a LAN / online race both computers must start with the same `--layout=` argument;
otherwise the join is refused as a different build.

| Id | File | What it tests |
|---|---|---|
| `exp_figure8_01` | `src/track/layouts/exp_figure8_01.tres` | Figure-eight with one elevated crossing (bridge on the first diagonal, s = 1440–2240 px). |

Layouts are `TrackLayout` resources; `elevation_zones` (arc-length intervals along the
centreline) mark elevated road. `TrackLayout.validate()` checks crossings, zone ends,
the grid and checkpoint placement. Layout ids are neutral and independent of the
visual theme variants.

## Road levels (J1)

On an elevated layout each car has a road level (0 ground, 1 bridge) from its
progress along its own branch; it changes only at the ends of an elevation zone,
which validation keeps clear of the other road. Ground cars use collision layer 2
and the ground barriers (layer 1); bridge cars use layer 8 and the bridge barriers
(layer 4) — so the two levels never touch, while cars on the same level collide as
everywhere else. Checkpoint gates are never on the bridge. A network client's own
(predicted) car uses the barriers of the level shown by the host's snapshots.

Not yet level-aware (later stages, J4): weapons. Missiles, mines and explosions use
flat 2D distance, so with weapons on they can hit a car on the other level at the
crossing. Test the prototype with No Guns for clean level behaviour.

Prototype fingerprints (fresh processes, `tests/support/sim_probe.gd`, layout
`exp_figure8_01`): `mode=spectate ticks=4800 weapons=0` → `7fb45fa02e9fcbfae31a1181a6fca7fa`,
`mode=race ticks=3600 weapons=0` → `a1d5d5c90f374570917f821a5b23e72b`.
