# Revit

## What it is

Revit is Autodesk's BIM (Building Information Modeling) authoring tool — the industry-standard platform architects and engineers use for actual construction documentation, schedules, and coordinated multi-discipline building models. It is a fundamentally different tool from [[Grasshopper]]: Revit models are parametric *building elements* (walls, floors, doors with real construction metadata) tracked in a single coordinated project database, not a free-form geometry/graph scripting environment.

## How geometry gets from Grasshopper into Revit

There is no single official bridge; the two realistic paths are:

- **Rhino.Inside.Revit**: an Autodesk/McNeel-supported add-in that runs an actual Rhino + Grasshopper session *inside* the Revit process, so a Grasshopper definition can read Revit model data as input and write Revit-native elements (walls, rooms, floors) as output, live, in the same session. This is the more direct and currently better-supported path for feeding a Grasshopper/Monoceros-generated layout into a real Revit model. Repo/docs: https://github.com/mcneel/rhino.inside
- **Dynamo**: Revit's own built-in visual scripting tool (also node-graph based, conceptually similar to Grasshopper but a separate product with its own component library). Geometry generated in Grasshopper can be exported (e.g. via a common exchange format, or by rebuilding the logic natively in Dynamo) and picked up by a Dynamo graph running inside Revit. This avoids needing Rhino.Inside but means either duplicating logic in Dynamo or relying on file-based/geometry-exchange interop, which is lossier and less live than Rhino.Inside.Revit.

## Why Revit itself isn't a good home for the interactive solver

Revit is not built for the room-solver interaction model:

- It has no native concept of a WFC-style possibility-space/entropy visualization per grid cell, and no lightweight way to add one without a full custom Revit add-in (Revit's API/SDK is C#/.NET and considerably heavier-weight than a Grasshopper component or script).
- Revit's own recompute model is oriented around a persistent, always-live building model with change tracking and worksharing (multi-user editing) — it's built for *documenting* a settled design, not for the flip a Grasshopper user makes constantly between many full-graph re-solves while exploring options. Grasshopper's disposable, solve-once-per-input-change model (see [[Grasshopper]]) is a much better fit for the "lock an option, get an entirely fresh grid of remaining possibilities" loop this project needs during the exploration phase.
- The practical shape this suggests: do the interactive WFC exploration in Grasshopper (with [[Monoceros]]), and only push the *final, architect-approved* layout into Revit (via Rhino.Inside.Revit or Dynamo) once locking/exploration is done — not the other way around.

## Key gotchas / links

- Rhino.Inside.Revit requires compatible Rhino + Revit version pairs; check current compatibility before assuming any given Revit version works.
- Dynamo and Grasshopper are not interchangeable or auto-convertible — a Monoceros-based definition would need to be rebuilt (or bridged via Rhino.Inside.Revit) to run natively in Dynamo/Revit.
- Rhino.Inside.Revit docs/samples: https://www.rhino3d.com/inside/revit/
