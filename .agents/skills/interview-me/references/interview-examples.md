# Interview Examples

Use these worked examples only after loading the core interview model and steps in
`SKILL.md`. Adapt the content to the user's evidence; do not copy assumptions.

## Initial model

```text
STATED SOLUTION (Y): Build a dashboard for metrics.
UNDERLYING OUTCOME (X): Track active experiments and decide which need attention; hypothesized.
XY-RISK: High — the user, decision, and success signal for the dashboard are unconfirmed.
HYPOTHESIS: You need a personal view of active experiments and their early results; a dashboard is a candidate interface, not a confirmed requirement.
CONFIDENCE: 30% — the user, desired decision, success signal, and data boundary are unknown.
EVIDENCE: The request asks for a dashboard for metrics.
HIGH-IMPACT UNKNOWNS: Who uses it; which decision it supports; what metrics matter; what is out of scope.
NEXT QUESTION: Who needs to make which recurring decision with this information?
GUESS: You are the primary user, because the request names neither a shared audience nor a reporting obligation.
```

## Self-contained high-information question

Avoid a broad question such as `What should the dashboard do?` when a sharper
contrast is available.

```text
CONTEXT: You requested a dashboard for support leads. It is confirmed that they review support work daily; it is still unknown whether their main goal is faster ticket triage or identifying recurring product issues.
WHY THIS MATTERS: These goals require different data, workflows, and success measures.
Q: Which of those two decisions should the dashboard help a support lead make first?
GUESS: Faster triage is likely the first priority because the dashboard is intended for daily use, but please reject that if recurring-issue analysis is more valuable.
```

## Challenging a conventional solution

```text
CONTEXT: The request names a conventional solution, but the decision it should enable remains unconfirmed.
WHY THIS MATTERS: Confirming the desired result keeps the conventional solution from becoming an untested requirement.
Q: If you did not need to justify the conventional solution, what result would you actually choose?
GUESS: The outcome matters more than preserving the named solution, because the request describes an artifact rather than a decision it enables.
```
