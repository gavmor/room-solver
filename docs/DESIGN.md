# room-solver design doc — Revit-native pivot (2026-08-16)

Written outside-in: starting from what the architect actually sees and does, working inward toward the solver core. See [[Revit]] for the in-process hosting architecture this assumes, and the wiki-seed pages linked throughout for background on each concept.

## 1. What the architect experiences

The interaction model is unchanged by the pivot — this is the one constant across the whole rewrite:

1. Architect opens a room (or a defined boundary) in Revit; the add-in's modeless panel shows a grid overlaid on the room, one cell per discretized tile.
2. Every unlocked cell shows its **current possibility set** — every room-type/wall/door/corridor value still consistent with everything currently locked, rendered as a compact list or swatch group directly in the panel (and optionally as a lightweight overlay in the Revit view).
3. The architect clicks a value in some cell's possibility set. That cell is now **locked**.
4. The **entire solve re-runs from scratch**, with every locked cell (this one plus all prior locks) baked in as a fixed constraint. This is not a resume or an incremental step — it's a fresh full solve every time, which is deliberate (see [[WFC]] and [[AC-3-CSP]] on why "from scratch" is cheap and correct, not a compromise).
5. The panel refreshes with the new possibility set for every remaining unlocked cell.
6. Repeat until the architect is satisfied (all cells locked, or they accept a solver-filled remainder), then hits **Apply** — this is the only point anything touches the live Revit model.
7. Apply triggers reification: walls, rooms, and doors get created/updated in a single atomic transaction (see [[Revit]] §Reification).

Everything from step 2 onward has to complete fast enough to feel responsive after a click — this is the actual performance constraint, not per-keystroke incrementality (there is no incremental solver state; see step 4).

## 2. UI/panel layer

- A Revit **modeless dockable panel** (WPF), not a modal dialog — the architect needs to keep looking at the 3D/plan view while interacting with the grid.
- Per-cell possibility display: for small possibility sets (a handful of room types), a direct list/swatch works; for larger sets, prioritize the most-likely-by-weight options, with an expand-for-full-list affordance. This is a UI scaling concern, not a solver concern — the solver still needs to expose the *entire* domain to the UI layer regardless of how much of it gets rendered.
- Locking a cell = selecting a value → fires the async re-solve (§3) → panel re-renders from the new result.
- A **contradiction** (some cell's domain goes empty, or CP-SAT reports the model infeasible with the current locks) is a first-class UI state, not an error dialog: show which locked cells are jointly unsatisfiable if the solver can report that (CP-SAT can point at an infeasibility-relevant subset more readily than a WFC restart-on-failure can), and let the architect unlock one to recover — no silent failure, no crash.

## 3. Async bridge / orchestration layer

Standard Revit pattern (see [[Revit]] for the full code shape): lock action on the UI thread → `Task.Run` kicks the solve off-thread → result comes back → `RevitTask.RunAsync` re-enters the main thread only for the parts that need it (reading `Document` state for the next ingestion pass, or, on Apply, committing a `Transaction`). Nothing about the pivot changes this layer beyond "this is now the *only* execution context — no sidecar to fall back to if it's ever too slow."

## 4. Geometry ingestion / grid model

- `Room.GetBoundarySegments` → outer shell + internal cutouts (columns, shafts) → rasterize to a grid via polygon clipping + ray-casting (see [[Revit]]).
- Cells overlapping structural elements become **immutable void tiles** — modeled as permanently "locked" cells from the solver's point of view, not a special case the solver needs separate logic for. This is a deliberate simplification: void cells and architect-locked cells are the same mechanism (a fixed value pre-seeded into the model), just with different provenance and non-removability.
- This layer owns the boundary between Revit's continuous BIM geometry and the solver's discrete grid — it is the one place that translates between the two, so neither the solver core nor the UI needs to know about Revit geometry types directly (see AGENTS.md design principle 5: isolate data transforms from data consumers).

## 5. Solver core — and the WFC-vs-CP-SAT decision

This is the question Gavin raised directly: *"WFC seems to be a random-walk through a latent space that's potentially exhaustively delineable via constraint solving."* Worth answering deliberately rather than defaulting to "keep WFC because that's what the wiki already describes."

**The tension:**

- WFC's collapse step is stochastic by construction — lowest-entropy cell, weighted-random pick, propagate, repeat. That randomness is *useful* when the goal is organic, non-repetitive output (textures, game levels) and mildly harmful when the goal is an explainable, professional decision-support tool: an architect who locks the same three cells twice reasonably expects the same remainder, and when a solve fails, "these locks are unsatisfiable, specifically because X conflicts with Y" is a far better failure mode than "contradiction, restarting with a new seed."
- CP-SAT is already in-process for dimensional packing (`NoOverlap2D`, reified adjacency — see [[CP-SAT]]), so using it for collapse too isn't a new dependency, just a new use of an existing one. It can also carry an actual **objective function** (maximize south-facing living rooms, minimize corridor area, weight adjacency preferences) — something WFC's frequency-weighted-random selection only approximates.
- But CP-SAT is not free: it's an optimization/feasibility engine, not a domain-enumeration engine. Getting "the full remaining possibility set for cell C" out of CP-SAT in general means testing feasibility per candidate value (or per small candidate group) — more expensive per cell than WFC's built-in arc-consistency propagation, which computes reduced domains for *all* cells in one pass as a side effect of collapsing one.

**Decision: hybrid, not pure-either.**

- **WFC-style arc-consistency propagation stays as the possibility-set engine.** After every lock, run the WFC propagate step (cheap, already grid-shaped, gives every remaining cell's possibility set in one pass) to drive what the architect sees in step 2 of §1. This is the same mechanism the original plan always intended (see [[WFC]], [[AC-3-CSP]]) — the pivot doesn't change *this* part.
- **CP-SAT replaces random collapse as the "fill in the rest" / Apply-time engine.** When the architect hits Apply (or asks for "a concrete suggestion" rather than just the possibility set), build a CP-SAT model over all still-unlocked cells with all locks as fixed constraints, an objective function encoding the design preferences above, and solve for the (or a near-)optimal complete assignment. This replaces WFC's weighted-random tile pick with a deterministic, explainable, preference-optimizing choice — same locked-cell set always produces the same filled-in layout, and infeasibility comes back as a genuine proof, not a restart signal.
- **Controlled variety, if still wanted, becomes an explicit knob, not an accident.** If architects want to see alternatives rather than always the objective-optimal fill, that's a deliberate "show me another option" action — request the next-best solution from CP-SAT (or re-solve with a randomized tie-break/restart parameter) rather than relying on WFC's forced randomness as the only source of variety. This needs to be validated with an actual architect user before deciding whether it's needed at all; don't build it speculatively.
- Net effect: WFC keeps doing what it's structurally best at (fast, local, all-cells-at-once domain reduction for the live possibility-space UI); CP-SAT takes over the part WFC was never well-suited to structurally guarantee (a specific, explainable, preference-weighted complete solution). This directly answers Gavin's framing: yes, the latent space is exhaustively delineable via constraint solving — but arc-consistency propagation (which is what WFC's propagate step already is, see [[AC-3-CSP]]) remains the cheaper tool for the *possibility-set* half of the problem, so the answer isn't "replace WFC," it's "replace only WFC's random-guess step."

**Open items to revisit once real floorplans are tested:** whether [[WFC]]'s Hierarchical WFC (HWFC) decomposition (envelope → zoning → circulation → detail passes) is needed for performance at real floorplan scale, for both the propagation layer and the CP-SAT model size (`NoOverlap2D` scales roughly with room-count²).

## 6. Connectivity/egress repair pass

Neither WFC propagation nor a CP-SAT objective inherently guarantees every room can reach an exit — this is a known gap in both paradigms (see [[WFC]]). After a CP-SAT fill (§5) produces a complete candidate layout, run a **BFS/MST pass over the resulting room-adjacency graph** to detect isolated components and insert the minimum doors needed to connect them (and prune truly redundant connections). This runs as a distinct, final step — not folded into the CP-SAT objective — because door insertion here is a structural repair, not a preference to optimize, and keeping it separate keeps the CP-SAT model itself smaller and easier to reason about (single-source-of-truth: the CP-SAT model owns placement/sizing/adjacency-preference; the graph pass owns connectivity guarantees).

## 7. Reification back into Revit

Unchanged from [[Revit]]'s description: batch `Wall.Create()` inside one atomic `TransactionGroup`, Douglas-Peucker simplification before wall creation, minimal `Regenerate()` calls, `JoinGeometryUtils.JoinGeometry()` for junctions. This only runs on Apply, never on every lock — locks only drive the possibility-set re-solve (§5's WFC half), keeping the live model untouched until the architect explicitly commits.

## 8. Implementation fan-out: the shadowbranch blackboard

Five vertical slices, one agent each, each in its own isolated worktree/branch — no shared working directory, so no file-lock contention. Slices map directly to §2-§7 above:

| Slice | Branch | Owns |
|---|---|---|
| A — Add-in scaffold + async bridge + panel shell | `feature/revit-addin-scaffold` | §2-3: project/manifest scaffolding, `RevitTask`/`Revit.Async` wiring, modeless WPF panel shell, the `IExternalEventHandler` plumbing |
| B — Geometry ingestion / grid model | `feature/revit-addin-ingestion` | §4: `GetBoundarySegments` → grid/dual-graph conversion, void-cell handling, the shared `Cell`/`Grid` data model everyone else consumes |
| C — WFC possibility-set engine | `feature/revit-addin-wfc-propagation` | §5 (WFC half): arc-consistency propagation producing the live per-cell possibility set |
| D — CP-SAT fill + connectivity repair | `feature/revit-addin-cpsat-fill` | §5 (CP-SAT half) + §6: `Google.OrTools` model, objective function, BFS/MST connectivity repair |
| E — Reification | `feature/revit-addin-reification` | §7: `TransactionGroup`, Douglas-Peucker simplification, `JoinGeometryUtils` |

None of these branches merge into `main` (or into each other) without explicit confirmation back through the chain to Gavin — this is a fresh project with no established "merge freely" precedent yet (unlike, say, druthers' dev branch).

**The problem the blackboard solves:** these five slices have real interface dependencies (B defines the `Cell`/`Grid` model that C, D, and E all consume; C and D both need to agree on what a "domain"/"possibility set" object looks like; A needs to know the shape of whatever C/D return so the panel can render it) but the agents work in isolated worktrees and can't see each other's in-progress code. Without a coordination surface, they'd either block on each other serially (defeating the point of fanning out) or guess at interfaces and integrate badly at the end. Blanket "everyone will just check in on Slack" doesn't hold up here since these are agents, not people with a standing channel (see AGENTS.md design principle 4).

**Mechanics:**

- **One dedicated branch, `blackboard/revit-addin`**, created once off `main`, containing only coordination artifacts — never product code, never merged anywhere:
  - `.blackboard/interfaces.md` — the shared contract surface (C# interfaces/DTOs: `Cell`, `Grid`, `IPossibilitySetEngine`, `IFillSolver`, `ISolveResult`, etc.). Each type has one owning agent; sections are marked `PROPOSED` (posted, not yet depended on) or `ACCEPTED` (at least one other agent has started coding against it — now a soft freeze, changed only with a note in `decisions.md`).
  - `.blackboard/status.md` — append-only, one line per check-in: `[agent] slice — what's done, what's next, what I'm blocked on (if anything)`.
  - `.blackboard/decisions.md` — append-only log of any decision that affects more than one slice (e.g. "grid uses (row, col) not (x, y) — affects C, D, E").
  - `.blackboard/blockers.md` — append-only: blocker raised / blocker resolved, so an idle agent waiting on another's interface has one place to check instead of polling.
- **Conflict avoidance is structural, not procedural**: every file on this branch is append-only from each agent's own section/line — nobody edits another agent's prior entries. Append-only edits from independent agents are exactly the shape git merges without conflict, so agents `git fetch` + `git merge --ff-only` (or rebase if needed), append, commit, push — small, frequent commits, not batched.
- **Cadence**: at slice start (claim the slice, post assumed/needed interfaces to `interfaces.md`), at least once mid-slice (progress + any interface change), immediately on hitting or resolving a blocker, and at slice completion. This matches the existing convention from the Damselfly fan-out: frequent check-ins throughout, not just at completion (see `feedback-blackboard-frequent-checkins` in workspace memory).
- **Each agent's actual code** lives only on its own `feature/revit-addin-<slice>` branch/worktree — the blackboard branch is read/write for coordination text only, never a place code gets committed.
- **Integration is a separate, later, human-confirmed step**: once all five slices report done on `status.md`, a follow-up pass (not automatic) reconciles the branches against the accepted interfaces and integrates them — likely into a single `feature/revit-addin-integration` branch — before anything is proposed for `main`.

**If this isn't what "shadowbranch blackboard" meant:** this is a reasoned interpretation built from the one thing that *is* established convention here (frequent-checkin fan-outs, per-agent worktrees) plus first-principles design for the actual coordination problem (shared interfaces, no shared working directory) — not a recall of a pre-existing definition, since none exists in this workspace's memory. Flagging explicitly in the final report in case Gavin had something else in mind.

## Open decisions for Gavin

1. **IT lockdown posture** — worst-case assumed throughout (see [[Revit]]); confirm or relax.
2. **Controlled-variety UX** (§5) — is "show me another option" actually wanted, or is a single deterministic best-fill sufficient? Needs an architect user check-in, not a guess.
3. **Revit version target** — affects which API surface is safe to use; not yet decided.
4. **HWFC necessity** — deferred until real floorplan sizes are known; flagged, not decided.
