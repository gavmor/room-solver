# Wave Function Collapse (WFC)

## What it is

Wave Function Collapse is a procedural generation algorithm published by [Maxim Gumin](https://github.com/mxgmn/WaveFunctionCollapse) in 2016. It generates output that is *locally similar* to a small input example (or, in the "tiled model" variant, satisfies a set of adjacency rules between predefined tiles/modules) by treating generation as a constraint satisfaction problem:

1. **Initialize**: every cell in the output grid starts in *superposition* — it could be any of the available tiles/modules.
2. **Observe (collapse)**: pick the cell with the lowest Shannon entropy (fewest remaining options, weighted by tile frequency) and collapse it to a single concrete tile, chosen randomly weighted by that tile's frequency.
3. **Propagate**: for every neighbor of the collapsed cell, remove any tile options that are no longer compatible with the adjacency rules given the neighbor's new, reduced possibility set. This cascades outward (it's an [[AC-3-CSP|arc-consistency]] propagation pass) until no more options can be eliminated.
4. **Repeat** steps 2-3 until every cell has collapsed to one tile (success) or some cell's possibility set becomes empty (contradiction — the classic implementation backtracks or restarts on this).

The name is a physics metaphor: each cell is a "wave function" of possible states until it's "observed" and collapses to one.

## Why it's relevant to room-solver

This project's entire interaction model is built directly on top of WFC's structure:

- The **entropy/domain** the architect sees at each cell *is* the WFC possibility set from step 1/3 above — we're just surfacing the algorithm's internal state as the primary UI, rather than hiding it.
- **Locking a cell** is exactly a pre-collapse in step 2 — you're telling the solver "this cell's tile is fixed before you start," not injecting state into a mid-run solver.
- Because propagation (step 3) is a full pass over the grid from whatever the current collapsed/locked cells are, **there is no meaningful "resume" state to preserve** — re-running the entire algorithm from scratch with the locked cells pre-seeded produces the same result as if those locks had always been there. This is precisely why room-solver's "full re-solve on every lock" design isn't a shortcut or a compromise — it's the natural shape of the algorithm, and it happens to line up perfectly with Grasshopper's own solve-once graph execution model (see [[Grasshopper]]).

## Architectural-layout adaptations

Gumin's original WFC operates on pixel/voxel tiles for texture and level generation. Adapting it to floorplans/room layouts generally means:

- Tiles become **modules**: room types, wall segments, doors, corridors — each with explicit connector/socket definitions on each face (compatible edges must match, e.g. "corridor-end can only neighbor corridor-end or room-entrance").
- The grid is usually a 2D or 2.5D (multi-floor) grid rather than a single-plane texture.
- Frequency weighting doubles as a design lever — e.g. weighting corridor modules low keeps generated layouts room-dense rather than maze-like.
- [[Monoceros]] is the reference implementation this project targets for exactly this kind of module/slot/rule modeling inside Grasshopper.

## Key gotchas

- **Contradictions**: naive WFC can paint itself into a corner (a cell's domain becomes empty) and needs a backtrack or full restart. Because room-solver already restarts the whole solve on every lock, contradiction-handling is simpler here than in a typical live/incremental WFC UI — a contradiction just means "these locks are jointly unsatisfiable," surfaced as a solve failure rather than a partial-undo problem.
- **Determinism vs. seed**: the same locked-cell set plus the same RNG seed always produces the same solve. Useful for reproducing/debugging a specific layout.
- **Performance**: full-grid propagation on every lock is O(grid size × rule complexity) per lock, not free — worth profiling once the grid/tileset size for real floorplans is known.

## References

- Maxim Gumin, original repo: https://github.com/mxgmn/WaveFunctionCollapse
- Oskar Stålberg's talks on WFC-adjacent techniques (Townscaper, Bad North) are widely cited in the architectural-WFC community.
