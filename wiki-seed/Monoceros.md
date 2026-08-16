# Monoceros

**Superseded 2026-08-16.** room-solver pivoted away from Grasshopper entirely (see [[Revit]]) — WFC is now reimplemented natively in C# rather than depending on this plugin. This page is kept for historical context on the module/slot/rule vocabulary, which is still a useful reference for the native reimplementation's data model; do not treat the "distribution/licensing" or "targets Grasshopper" framing below as current.

## What it is

Monoceros is a free/open-source [[Grasshopper]] plugin for Rhino that implements [[WFC|Wave Function Collapse]] as a modular assembly tool, built by [Subdigital](https://sub.digital/) (studio of Ján Pernecký and collaborators). It's aimed at architects and designers assembling discrete modules (rooms, structural bays, building blocks, urban fragments) according to adjacency rules, rather than at texture/level generation.

- Homepage: https://www.monoceros.tools/
- Source: https://github.com/subdgtl/Monoceros
- Distribution: https://www.food4rhino.com/en/app/monoceros

## How it models the problem

Monoceros' core vocabulary maps directly onto the WFC concepts room-solver needs:

- **Module**: a piece of geometry (a room type, a structural element, a piece of furniture) with named connectors on each of its faces/sides.
- **Slot**: a single cell in the output grid/lattice — the equivalent of a WFC "cell in superposition." Each slot tracks which modules are still allowed to occupy it.
- **Rule**: an adjacency constraint between two module connectors — "connector A on module X may neighbor connector B on module Y." Rules can be authored explicitly or (in later versions) inferred automatically from example assemblies.
- The solve itself is Monoceros' WFC **Solver** component, which runs the standard collapse+propagate loop (see [[WFC]]) across all slots until every slot is resolved to one module or the solve reports a contradiction.

This is a very close structural match to room-solver's needs: "module" ≈ room/wall/door type, "slot" ≈ grid cell, "rule" ≈ our adjacency constraints, and Monoceros' Solver already does full-grid collapse+propagate in one pass — which is exactly the "re-run from scratch" behavior the project's interaction model wants (see [[Grasshopper]] for why that fits Grasshopper's execution model so well).

## Locking cells with Monoceros

Monoceros supports constraining specific slots before the solve — you can pre-assign a known module to a slot, and the Solver treats it as fixed input rather than something to collapse. This is the direct hook room-solver's "lock" UI action needs to use: a locked cell in the UI becomes a pre-assigned slot value fed into the Solver component, and every lock change just means feeding a different pre-assignment set into the same graph before the next recompute.

## Entropy/possibility-space preview

Open question tracked for the [[Grasshopper]]/spike-B work: does Monoceros expose a first-class "remaining possibilities per slot" preview component, or does the UI need to read the Solver's intermediate/output data structures directly and build a custom preview? Check the spike-B findings and the plugin's component reference before assuming either way — this directly determines how much custom Grasshopper/Rhino display-pipeline work the entropy visualization needs.

## Key gotchas

- Monoceros needs explicit connector definitions per module face; getting these wrong is the most common source of "solver reports no valid assignment" contradictions — worth validating rule sets on a small module set before scaling up a real floorplan tileset.
- It's a compiled Grasshopper plugin (not pure canvas-native components), so distribution/versioning of the `.gha` matters if this project is shared with other architects — pin a Monoceros version once the spike stabilizes.
- Licensing: check current Monoceros licensing/pricing terms on monoceros.tools before assuming it's fully free for downstream/commercial use — the "Buy" link on the homepage suggests there may be a paid tier alongside the free/open plugin.
