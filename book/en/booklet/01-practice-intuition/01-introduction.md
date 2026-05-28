# Introduction to Formal Verification

Formal verification is a way to make system behavior checkable by turning requirements into precise properties and checking them against a model or program.

In Oxpecker, the first motivation is AI-assisted development. If an agent changes code quickly, the reviewer still needs evidence that the change preserves important behavior. Tests and human review remain useful, but they often inspect selected paths. Formal verification asks a different question: what states and transitions are possible under the model, and can any of them violate a property?

This chapter introduces the vocabulary that later chapters use: state, transition, reachable state, invariant, model checking, and counterexample trace.

