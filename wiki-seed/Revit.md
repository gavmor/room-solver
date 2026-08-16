# Revit

## What it is

Revit is Autodesk's BIM (Building Information Modeling) authoring tool — the industry-standard platform architects and engineers use for construction documentation, schedules, and coordinated multi-discipline building models. Revit models are parametric *building elements* (walls, floors, doors with real construction metadata) tracked in a single coordinated project database.

## Status: primary target (pivoted 2026-08-16)

Revit is now room-solver's **only** target platform — not a downstream recipient of a Grasshopper-authored layout, but the environment the entire interactive solve-and-lock loop runs in. This pivot was driven by wanting to target an **enterprise environment with locked-down application provisioning**, where Revit is presumably already the sanctioned/installed tool and a second licensed app (Rhino + Grasshopper) would need its own separate IT approval, install, and patching cycle — friction this project is specifically trying to avoid.

**Working assumption, stated explicitly so it's easy to revisit:** the IT lockdown posture is worst-case until confirmed otherwise — no local admin rights, AppLocker/WDAC blocking unsigned or unapproved binaries, no outbound network access. Everything in this page follows from that assumption. If Gavin later confirms a looser environment (e.g. outbound access to localhost is fine, or unsigned binaries are permitted with an exception), some of the constraints below relax — see [[CP-SAT]] and [[Prolog]] for what specifically would change.

## Architecture: single in-process, signed add-in DLL

No sidecar process, no IPC, no network egress. Everything happens inside `Revit.exe`'s AppDomain:

- Revit's UI is Single-Threaded Apartment (STA), bound to the main thread — heavy solver compute cannot run synchronously without freezing the UI.
- The standard fix is the async bridge pattern: wrap `IExternalEventHandler`/`ExternalEvent` in a `TaskCompletionSource<T>` so external code can `await` a hop onto Revit's main thread. Two mature libraries do this: [Revit.Async](https://github.com/KennanChan/Revit.Async) and [ricaun.Revit.UI.Tasks](https://github.com/ricaun/Revit.UI.Tasks).
- Shape: `await Task.Run(() => solve())` runs the WFC/CP-SAT solve off-thread; `await RevitTask.RunAsync(...)` re-enters the main thread to open a `Transaction`, build/modify elements, and commit.

```csharp
public Result OnStartup(UIControlledApplication application) {
  RevitTask.Initialize(application);
  return Result.Succeeded;
}

public async Task ExecuteSolveAsync(Document doc, SpatialContext context) {
  PlanSolution solution = await Task.Run(() => {
    var solver = new SpatialConstraintEngine();
    return solver.ComputeLayout(context);
  });
  await RevitTask.RunAsync(app => {
    using (Transaction trans = new Transaction(doc, "Apply Layout")) {
      trans.Start();
      LayoutReificationEngine.ApplySolution(doc, solution);
      trans.Commit();
    }
  });
}
```

This is the *in-process modeless task bridge* topology — the most isolated-from-the-network of the three architectures considered, and the only one viable under the worst-case lockdown assumption. The other two (out-of-process sidecar daemon; cloud-distributed worker) both require spawning a separate process or reaching the network, and are explicitly ruled out here.

## Geometry ingestion

Use Revit's native API directly — no Grasshopper geometry import layer needed:

- `Room.GetBoundarySegments(SpatialElementBoundaryOptions { SpatialElementBoundaryLocation = Finish, StoreFreeBoundaryFaces = true })` returns `IList<IList<BoundarySegment>>` — the first sublist is the outer shell, subsequent sublists are internal cutouts (columns, shafts, mechanical chases).
- Convert the vector polygons to a raster grid/dual graph via polygon clipping + ray-casting; cells outside the boundary or overlapping structural columns become immutable void tiles — these become the fixed cells the solver treats as pre-locked.

## Reification back into the model

- Batch `Wall.Create()` calls inside a single atomic `TransactionGroup` so a lock/re-solve either fully commits or fully rolls back — never leaves a half-applied layout.
- Simplify collinear grid boundaries via Douglas-Peucker line simplification before wall creation, to avoid fragmented micro-walls.
- Avoid unnecessary `doc.Regenerate()` calls — only regenerate when a dependent family instance (e.g. a door) needs updated host geometry.
- Clean up wall junctions with `JoinGeometryUtils.JoinGeometry()`.
- Because everything is in-process, the serialization step a sidecar architecture would need (to cross an IPC boundary) is unnecessary here — boundaries, room types, and adjacency data can be passed as plain in-memory objects between the ingestion, solve, and reification stages.

## End-to-end pipeline

1. `OnStartup` registers the async bridge (`RevitTask.Initialize` or equivalent) and the modeless panel.
2. On user action, the main thread reads the selected room boundary via `GetBoundarySegments`.
3. Boundary/egress/room-type/adjacency data is handed to the solver as in-memory objects (no serialization needed — see above).
4. The solver runs off-thread via `Task.Run` (see [[WFC]] and [[CP-SAT]] for what runs here).
5. The architect locks a cell in the possibility-space UI; the *entire* solve re-runs from scratch with all locked cells baked in as fixed constraints (this project's core interaction model — unchanged by the pivot).
6. Once approved, `RevitTask.RunAsync` re-enters the main thread, opens an atomic `TransactionGroup`, builds walls, hosts doors, creates `Room` elements, runs `JoinGeometryUtils`, and commits.

## Key gotchas / open items

- Signing: the add-in DLL needs a valid code-signing certificate accepted by the target environment's AppLocker/WDAC policy — get the exact signing requirement from IT before build/release tooling is finalized.
- The worst-case lockdown assumption above is unconfirmed. If it turns out to be wrong in either direction, revisit: looser IT (e.g. an approved sidecar process is fine) reopens Clingo/CLP(FD) as viable (see [[Prolog]]); tighter IT (e.g. even NuGet-restored native dependencies inside Google.OrTools are rejected by WDAC) would put CP-SAT itself at risk and is worth a design fallback.
- Revit API version targeting (which Revit year(s) to support) is not yet decided — affects which Revit API surface (e.g. newer `GetBoundarySegments` overloads) is safe to use.
