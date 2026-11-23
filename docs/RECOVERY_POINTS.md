# Recovery points

Known states of HyperCars you can go back to. This session's git access refuses tag
pushes, so each recovery point is a **backup branch** on GitHub. Recovery branches are
never moved or overwritten; development continues on `claude/festive-hypatia-15k6fj`.

## How to look at or recover a state

Inspect a state without changing anything (a throw-away folder beside your project):

```bash
git fetch origin
git worktree add ../HyperCars-rp0 origin/backup-20261123-presentation-rp0
```

Open `../HyperCars-rp0` in Godot 4.7.2 to play or test that state. Remove it when done:

```bash
git worktree remove ../HyperCars-rp0
```

Start new work from a recovery point (a new branch; nothing existing is touched):

```bash
git switch -c my-restart origin/backup-20261123-presentation-rp0
```

Compare a recovery point with the current work:

```bash
git diff origin/backup-20261123-presentation-rp0 origin/claude/festive-hypatia-15k6fj --stat
```

Never force-push, reset or delete a recovery branch to "restore" it: create a new
branch from it instead.

## Recovery points

| Name | Git reference | Commit | State | Validation | Known limitations |
|---|---|---|---|---|---|
| Pre-stabilization | `backup-20261122-pre-stabilization` | `630f25a` | Before the Stabilization & Pre-Completion Pass (2026-11-22) | Full suite 738 / 738 (2026-11-20) | Night high beam, network results and UI overlaps not yet fixed (fixed later) |
| RP0 — Pre-Presentation | `backup-20261123-presentation-rp0` | `3eb6afa` | "The Road to 1.0" complete: career, ending, wheels, defects | Full suite 771 / 771 on the same code (the last commits only changed docs) | See `docs/COMPLETION_READINESS.md` at that commit |
