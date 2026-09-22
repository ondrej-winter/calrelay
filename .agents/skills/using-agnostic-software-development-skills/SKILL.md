---
name: using-agnostic-software-development-skills
description: Discover and invoke technology-agnostic software development skills. Use when starting general engineering work or deciding which reusable workflow skill applies to a task.
metadata:
  version: "2.5.0"
  dependencies:
    tools: []
    skills:
      - name: add-observability
        purpose: Route observability, logging, metrics, tracing, profiling, and dashboard work.
        required: false
        relationship: route
      - name: api-and-interface-design
        purpose: Route API and interface contract design work.
        required: false
        relationship: route
      - name: author-agent-skill
        purpose: Route Agent Skill creation, update, and review work.
        required: false
        relationship: route
      - name: author-agents-config
        purpose: Route repository coding-agent instructions, scoped policy, client adapters, and configuration migration work.
        required: false
        relationship: route
      - name: browser-runtime-verification
        purpose: Route browser-based verification of UI behavior.
        required: false
        relationship: route
      - name: ci-cd-and-automation
        purpose: Route CI/CD pipeline and automation work.
        required: false
        relationship: route
      - name: code-review-and-quality
        purpose: Route code review and quality gate work.
        required: false
        relationship: route
      - name: code-simplification
        purpose: Route behavior-preserving complexity reduction work.
        required: false
        relationship: route
      - name: conventional-commits
        purpose: Route Conventional Commits message writing, review, and validation work.
        required: false
        relationship: route
      - name: context-engineering
        purpose: Route work that needs better task context before implementation.
        required: false
        relationship: route
      - name: debugging-and-error-recovery
        purpose: Route broken behavior, error recovery, and root-cause analysis work.
        required: false
        relationship: route
      - name: deprecation-and-migration
        purpose: Route deprecation, migration, and old-system removal work.
        required: false
        relationship: route
      - name: documentation-and-adrs
        purpose: Route documentation and architecture decision work.
        required: false
        relationship: route
      - name: doubt-driven-development
        purpose: Route high-stakes or unfamiliar implementation decisions for adversarial review.
        required: false
        relationship: route
      - name: frontend-ui-engineering
        purpose: Route browser-facing UI implementation and refinement work.
        required: false
        relationship: route
      - name: git-workflow-and-versioning
        purpose: Route branch, commit, and version-control workflow work.
        required: false
        relationship: route
      - name: hexagonal-vertical-slices
        purpose: Route architecture design, review, or refactoring work involving hexagonal architecture and vertical feature slices.
        required: false
        relationship: route
      - name: idea-refine
        purpose: Route rough concepts that need structured refinement.
        required: false
        relationship: route
      - name: incremental-implementation
        purpose: Route implementation work that should be built and verified in slices.
        required: false
        relationship: route
      - name: interview-me
        purpose: Route unclear user intent that needs discovery before planning.
        required: false
        relationship: route
      - name: performance-optimization
        purpose: Route measurement-driven performance investigation and optimization work.
        required: false
        relationship: route
      - name: planning-and-task-breakdown
        purpose: Route work that needs decomposition into verifiable tasks.
        required: false
        relationship: route
      - name: review-implementation-plan
        purpose: Route implementation plan review work.
        required: false
        relationship: route
      - name: run-local-quality-gate
        purpose: Route local formatting, linting, static analysis, test, and build validation work.
        required: false
        relationship: route
      - name: security-and-hardening
        purpose: Route security review and hardening work.
        required: false
        relationship: route
      - name: shipping-and-launch
        purpose: Route deployment, launch, monitoring, and rollback-readiness work.
        required: false
        relationship: route
      - name: source-driven-development
        purpose: Route implementation that needs verification against authoritative sources.
        required: false
        relationship: route
      - name: spec-driven-development
        purpose: Route requirements and acceptance criteria definition before code.
        required: false
        relationship: route
      - name: test-driven-development
        purpose: Route work that should be driven by tests or test additions.
        required: false
        relationship: route
      - name: update-project-docs
        purpose: Route project documentation updates.
        required: false
        relationship: route
      - name: write-adr
        purpose: Route architecture decision record creation and updates.
        required: false
        relationship: route
---

# Using Agnostic Software Development Skills

## Overview

The agnostic software development collection contains reusable engineering
workflow skills organized by development phase. This catalog helps you discover
and apply the right technology-independent skill for the current task. Use a
technology-specific collection catalog alongside this one when the task also
needs language or platform mechanics.

## Steps

At the start of a task, identify the development phase and apply the corresponding
skill.

1. Classify the task by the user's current need.
2. Select the primary skill that matches the first applicable phase.
3. Add secondary skills only when their trigger is directly present.
4. Confirm that each selected skill is available in the current environment. If it
   is unavailable, report that limitation instead of inventing its instructions.
5. Check each selected skill's declared capabilities before activation. Stop when
   a required capability is unavailable. When an optional capability is unavailable,
   use only the skill's documented fallback and label the execution as degraded.
6. Follow each selected skill's steps, including verification.
7. Report the selected skills, validation evidence, degraded fallbacks, and any
   remaining limitations in the task handoff.

Use this routing guide:

```
Task arrives
- User does not know what they want yet: interview-me
- Have a rough concept and need variants: idea-refine
- Requirements are incomplete, conflicting, scattered, or need durable agreement: spec-driven-development
- Precise fix or small edit with clear acceptance criteria: work directly from the request
- Have settled requirements and need tasks: planning-and-task-breakdown
  - Need plan review before coding: review-implementation-plan
- Implementing a multi-file or non-minimal change: incremental-implementation
  - For each behavior change that automated tests can verify, apply test-driven-development inside the slice before implementation
  - Hexagonal architecture or vertical-slice boundary work: hexagonal-vertical-slices
  - UI work: frontend-ui-engineering
  - API work: api-and-interface-design
  - Need better context: context-engineering
  - Need doc-verified code: source-driven-development
  - Stakes high or unfamiliar code: doubt-driven-development
- Implementing a minimal testable behavior change or regression fix: test-driven-development directly
- Need browser runtime evidence: browser-runtime-verification
- Need full local quality checks: run-local-quality-gate
- Adding logs, metrics, traces, profiling, or dashboards: add-observability
- Something broke: debugging-and-error-recovery
- Reviewing code: code-review-and-quality
  - Too complex: code-simplification
  - Security concerns: security-and-hardening
  - Performance concerns: performance-optimization
- Committing or branching: git-workflow-and-versioning
  - Need Conventional Commits syntax or review: conventional-commits
- CI/CD pipeline work: ci-cd-and-automation
- Deprecating or migrating: deprecation-and-migration
- Writing docs or ADRs: documentation-and-adrs
  - Need a project documentation update: update-project-docs
  - Need an architecture decision record: write-adr
- Creating, updating, or reviewing skills: author-agent-skill
- Creating, auditing, or synchronizing repository agent instructions and client adapters: author-agents-config
- Deploying or launching: shipping-and-launch
```

## Dependency metadata contract

Use these canonical capability names in this collection:

- `shell-execution`: run local commands or scripts
- `version-control`: inspect or modify repository history and state
- `browser-runtime`: observe behavior in a real browser
- `source-retrieval`: access authoritative local or remote sources
- `independent-review`: obtain a fresh-context or independent review

Set `required: true` when the skill cannot produce its stated outcome without the
capability or dependency. Set `required: false` only when the dependency is
conditional or the skill documents a usable fallback.

Classify each referenced skill with one `relationship`:

- `route`: select the skill when its own activation trigger matches the task
- `handoff`: transfer a defined part of the workflow when the current skill says to
- `verification`: use the skill to gather evidence for an outcome
- `awareness`: coordinate with its constraints without activating it automatically

Optional related skills are not recursively activated merely because they are
listed. Activate them only when their own trigger is present or an explicit
handoff step requires them.

## Core Operating Behaviors

These behaviors apply at all times, across all skills. They are non-negotiable.

### 1. Surface Assumptions

Before implementing anything non-trivial, explicitly state your assumptions:

```
Assumptions I am making:
1. [assumption about requirements]
2. [assumption about architecture]
3. [assumption about scope]
Correct me now or I will proceed with these.
```

Don't silently fill in ambiguous requirements. The most common failure mode is making wrong assumptions and running with them unchecked. Surface uncertainty early — it's cheaper than rework.

### 2. Manage Confusion Actively

When you encounter inconsistencies, conflicting requirements, or unclear specifications:

1. Stop and do not proceed with a guess.
2. Name the specific confusion.
3. Present the tradeoff or ask the clarifying question.
4. Wait for resolution before continuing.

**Bad:** Silently picking one interpretation and hoping it's right.
**Good:** "I see X in the spec but Y in the existing code. Which takes precedence?"

### 3. Push Back When Warranted

You are not a yes-machine. When an approach has clear problems:

- Point out the issue directly
- Explain the concrete downside (quantify when possible — "this adds ~200ms latency" not "this might be slower")
- Propose an alternative
- Accept the human's decision if they override with full information

Sycophancy is a failure mode. "Of course!" followed by implementing a bad idea helps no one. Honest technical disagreement is more valuable than false agreement.

### 4. Enforce Simplicity

Your natural tendency is to overcomplicate. Actively resist it.

Before finishing any implementation, ask:

- Can this be done in fewer lines?
- Are these abstractions earning their complexity?
- Would a staff engineer look at this and say "why didn't you just..."?

If you build 1000 lines and 100 would suffice, you have failed. Prefer the boring, obvious solution. Cleverness is expensive.

### 5. Maintain Scope Discipline

Touch only what you're asked to touch.

Do not:

- Remove comments you don't understand
- "Clean up" code orthogonal to the task
- Refactor adjacent systems as a side effect
- Delete code that seems unused without explicit approval
- Add features not in the spec because they "seem useful"

Your job is surgical precision, not unsolicited renovation.

### 6. Verify, Don't Assume

Every skill includes a verification step. A task is not complete until verification passes. "Seems right" is never sufficient — there must be evidence (passing tests, build output, runtime data).

## Failure Modes to Avoid

These are the subtle errors that look like productivity but create problems:

1. Making wrong assumptions without checking
2. Not managing your own confusion — plowing ahead when lost
3. Not surfacing inconsistencies you notice
4. Not presenting tradeoffs on non-obvious decisions
5. Being sycophantic ("Of course!") to approaches with clear problems
6. Overcomplicating code and APIs
7. Modifying code or comments orthogonal to the task
8. Removing things you don't fully understand
9. Skipping needed requirements clarification or specification because "it's obvious"
10. Skipping verification because "it looks right"

## Skill Rules

1. **Check for an applicable skill before starting work.** Skills encode processes that prevent common mistakes.

2. **Skills are workflows, not suggestions.** Follow the steps in order. Don't skip verification steps.

3. **Multiple skills can apply.** A feature implementation might use `idea-refine`, then `spec-driven-development` if requirements need durable agreement, then `planning-and-task-breakdown`, and then `incremental-implementation`. Within each behavior slice that automated tests can verify, apply `test-driven-development` before writing the implementation. Follow with only the review, simplification, documentation, version-control, or launch workflows whose triggers are present.

4. **The routed skill's activation rules are authoritative.** Use `spec-driven-development` when requirements are incomplete, conflicting, scattered, or need a durable agreement. For a precise fix or small edit with clear acceptance criteria, work directly from the request. Do not activate a skill merely because it appears in a catalog example.

## Lifecycle and catalog reference

Not every task needs every skill. Compose only the workflows whose triggers are
present. For a conditional lifecycle graph and the full phase-by-phase skill
table, see `references/catalog-reference.md`.
