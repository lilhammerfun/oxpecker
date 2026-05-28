# Specification Interface

A specification interface is the boundary between a system model and the checker.

In Oxpecker, a specification describes the state type, the initial state, possible actions, and invariants. This structure lets the checker explore the model without knowing the business domain.

For review, this separation matters: the reviewer can inspect the property being checked separately from the implementation that the agent changed.

