# Documentation standards: clear, concise, useful

Use these rules to keep source documentation useful without being verbose.

This file governs documentation written inside source code. Requirements for README updates, ADRs, and changelog notes live in `005-docs-and-adr.md`.

## Documentation principles

- Prefer concise explanations of contracts, invariants, side effects, concurrency rules, ownership, and intent.
- Use documentation comments to add information that names and types do not already make obvious.
- Public APIs and non-obvious behavior deserve better documentation than trivial private helpers.
- Document units, timezones, encodings, actor isolation, cancellation behavior, idempotency, mutability, ownership, security, and trust-boundary assumptions when callers need them.

## Type documentation

- Document public types, protocols, actors, and property wrappers when their responsibility or lifecycle is not obvious.
- Describe key invariants and ownership expectations.
- Omit implementation details unless consumers must know them.
- Small private data holders may omit documentation when names and types are already sufficient.

## Function and method documentation

- Document public callables and any private callable with non-obvious behavior, side effects, concurrency rules, cancellation behavior, or tricky contracts.
- Start with a short summary sentence.
- Document parameters, returns, thrown errors, cancellation, main-actor requirements, and side effects only when they add real value for callers.
- Avoid repeating type signatures in prose unless clarification is needed.

## Examples in documentation

- Keep examples minimal, executable when practical, and synchronized with real behavior.
- Prefer tested examples or snippets copied from working code over illustrative pseudocode that can silently go stale.
- Do not include real secrets, private endpoints, personal data, or user document contents in examples.

## Inline comments

- Use sparingly for non-obvious logic only.
- Explain why, not what.
- Prefer self-documenting code with clear names and simple logic over explanatory noise.
- Tag temporary workarounds with an issue or reference when possible.

## What not to document in code

- Feature lists belong in README or product docs.
- Architecture rationale belongs in ADRs.
- Performance claims belong in benchmarks or docs.
- Marketing language does not belong in source comments.
- Redundant restatements of names or type signatures should be removed.
