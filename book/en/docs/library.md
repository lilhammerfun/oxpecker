# Library Interface

The current library direction is organized around a small set of concepts:

- `Spec` defines the model boundary.
- `Action` defines one possible transition.
- `Invariant` defines a property that must hold for every reachable state.
- `CheckResult` reports whether the model holds or violates a property.
- `TraceStep` explains how a counterexample was reached.

`State` values are copied into the checker queue and counterexample traces.
The current API expects `State` to be a non-owning, copyable model value; result
deinitialization only frees checker-owned trace storage.

The interface should remain explicit enough for reviewers to understand what was checked.
