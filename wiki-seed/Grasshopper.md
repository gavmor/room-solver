# Grasshopper

## What it is

Grasshopper is the visual/algorithmic scripting environment built into [Rhino](https://www.rhino3d.com/) (Rhinoceros 3D). Instead of writing sequential code, you wire together **components** (nodes) into a **definition** (graph): each component takes typed inputs, does one job, and produces typed outputs that feed downstream components. It's the dominant visual-scripting tool in architecture/computational-design practice, which is why it's this project's primary target platform, with [[Monoceros]] as the WFC engine running inside it.

## The solve-once, pull-based execution model

This is the part of Grasshopper that directly shapes room-solver's interaction design, so it's worth being precise about:

- Grasshopper's graph is **pull-based and stateless between solves**: when any input changes (a slider moves, a value is edited, an upstream component's output changes), Grasshopper recomputes the entire dependent subgraph from that point downward. There's no persistent "solver session" you incrementally step — every recompute is a fresh evaluation of the graph given its current inputs.
- This is called a **solve** (Grasshopper explicitly labels it — the status bar shows "Solution complete" after each one), and it can be triggered automatically (on any input change) or manually (F5 / the "Recompute" button), which is exactly the "recompute is triggered live/manually" language in the spike-B task.
- Because there's no incremental solver state to manage, feeding room-solver's locked-cell set into the graph as just another input (e.g. a list of fixed slot→module pairs) and recomputing is the *native* way Grasshopper already works — nothing special has to be built to support "restart on lock." This is the core reason Grasshopper (with Monoceros as the WFC engine) is the primary target rather than an incremental/steppable custom solver.

## Why this matters for room-solver specifically

The project's settled decision — full WFC re-solve from scratch on every architect lock, no steppable solver — isn't a compromise made *despite* targeting Grasshopper; it's the design that Grasshopper's own execution model makes cheap and natural. A custom incremental WFC solver would actually fight the platform. See [[WFC]] for why re-solving from scratch is also cheap algorithmically, not just Grasshopper-idiomatic.

## Key gotchas / links

- Grasshopper ships with Rhino (Rhino 6+); no separate license needed once Rhino is licensed.
- Custom logic beyond what off-the-shelf components (like Monoceros') provide is written as **C# / Python script components** or full **compiled plugin components** (`.gha` files, what Monoceros ships as) — worth knowing the difference if a custom entropy-preview component turns out to be needed (see the open question in [[Monoceros]]).
- Grasshopper definitions save as `.gh` (binary) or `.ghx` (XML) — `.ghx` is the only one that's remotely hand-authorable/scriptable outside the Rhino/Grasshopper UI itself, which matters for how this project's spike-B artifact gets produced without a live Rhino session.
- Getting geometry *out* of Grasshopper into other tools (like Revit) is a separate interop question — see [[Revit]].
- Official reference: https://www.rhino3d.com/features/grasshopper/
