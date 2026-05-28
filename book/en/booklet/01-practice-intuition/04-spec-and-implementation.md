# Specification and Implementation

A useful formal model should eventually connect back to implementation behavior.

The early Oxpecker examples keep the model small enough to inspect directly. The next step is to compare the expected transition from the specification with the transition performed by a candidate implementation.

This is the beginning of the real workflow: an agent changes implementation code, and Oxpecker checks whether the observed transition still follows the specification.

