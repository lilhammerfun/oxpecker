# Explicit-State Model Checking

Explicit-state model checking explores reachable states one by one.

The checker starts from an initial state, applies every allowed transition, records every new state, and checks whether any reachable state violates a property. If a violation is found, the useful output is not just “failed”; it is the event trace that reproduces the failure.

For agent-generated code, this trace is review evidence. It tells the reviewer which sequence of events makes the generated behavior unsafe.

