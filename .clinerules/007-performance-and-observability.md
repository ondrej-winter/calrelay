# Performance and observability

Use these rules to keep performance expectations explicit, regressions visible, and runtime behavior traceable.

## Performance budgets and baselines

- **Should** define latency, responsiveness, memory, launch-time, energy, and error-budget expectations for user-facing or operationally critical workflows.
- **Should** make budgets measurable rather than using vague "fast enough" language.
- **Must** benchmark representative workloads before claiming a performance improvement on a hot path.
- **Must not** make performance claims from toy inputs or unrepresentative datasets when real user behavior is the concern.
- **Should** avoid introducing heavy dependencies without evidence from profiling or measurement.

## macOS responsiveness

- **Must** keep the main actor responsive. Do not perform blocking disk, network, database, parsing, or CPU-heavy work on the main actor.
- **Should** measure app launch, first useful interaction, window opening, large document loading, search/filtering, rendering, and background task behavior when those workflows are important.
- **Should** use cancellation and back-pressure for user-driven repeated actions such as search, filtering, refresh, and indexing.
- **Should** watch memory growth in long-running menu bar apps, agents, document apps, and background workers.

## Profiling expectations

- **Should** profile when changing hot paths such as rendering, parsing, persistence, search, indexing, networking, or file-system traversal.
- **Must** capture before/after numbers when optimizing.
- **Should** note the dataset, device class, OS version, build configuration, and environment when numbers drive a decision.
- **Should** measure memory allocation and energy behavior as well as latency when the workflow is data-heavy, UI-heavy, or long-lived.
- **Should** use Instruments, XCTest performance tests, signposts, or project-specific benchmarks as appropriate.

## Logging, tracing, and metrics

- **Should** instrument critical workflows with at least duration, success/failure, and volume counters when the project's observability stack supports it.
- **Should** use `os_signpost` or equivalent instrumentation around expensive UI, parsing, persistence, and external I/O workflows when profiling value is high.
- **Should** add measurements for long-running steps such as indexing, file import/export, network sync, rendering, and persistence migration.
- **Must** keep metric labels and log context low-cardinality; avoid raw file paths, user identifiers, document contents, queries, or other highly variable values as labels.
- **Should** propagate request, correlation, operation, or document IDs across adapter boundaries when available and safe.
- **Should** sample or rate-limit especially noisy diagnostic logs in tight loops, retries, file watchers, notifications, or high-volume code paths.
- **Must** apply the same sensitive-data rules to metrics, signposts, and traces that apply to logs.

## Operational notes

- **Should** add troubleshooting notes when new failure modes are introduced.
- **Should** document dashboards, logs, diagnostics, or support-bundle hooks for new critical paths when they exist.
- **Should** document alert thresholds or operational ownership when a new workflow meaningfully changes support expectations.
- **Must** document new observability hooks in README, support docs, or an ADR when they affect operation or user support.
