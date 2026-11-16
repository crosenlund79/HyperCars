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
