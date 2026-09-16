# 0001. Launch the Normal App at Login for Scheduled Sync

Date: 2026-09-16
Status: Accepted

## Context

CalRelay's macOS automation is intended to keep relayed availability reliably
current with minimal ongoing user effort. Timer-based reconciliation can run only
while the app process is alive, but requiring the user to remember to launch the
app after every login would undermine that outcome.

Running reconciliation after the normal app has exited would require a helper,
LaunchAgent, background-only process, or comparable lifecycle architecture. Such
an architecture would add permissions, signing, packaging, rollback, recovery,
and user-trust consequences that are not required to meet the current one-hour
freshness target.

## Decision

Enabling scheduled synchronization will also enable launch-at-login for the
normal Dock-visible `CalRelay.app`. The healthy login launch will keep the main
window closed; the app will open its control panel when setup or recovery
requires user action.

Scheduled synchronization will stop when the normal app process is not running.
Helper apps, LaunchAgents, background-only processes, and other closed-app
execution remain deferred and require a later explicit product decision and a
new ADR.

## Consequences

### Positive

- Scheduled sync resumes after login without requiring a separate helper target.
- The app retains one visible, recoverable identity for permission, status, and
  lifecycle controls.
- The decision supports the accepted freshness target without prematurely adding
  signing and packaging complexity.

### Negative

- Explicit Quit, crashes, and other periods when the normal app is not running
  pause synchronization.
- Launch-at-login registration becomes part of automation health and needs
  visible recovery behavior.
- Users who disable launch-at-login while retaining scheduling receive degraded
  post-login freshness.

### Neutral

- Pausing scheduled sync does not automatically disable launch-at-login.
- Explicit Quit does not disable either persisted preference; the app can resume
  at the next manual launch or login.
- This ADR selects a lifecycle boundary, not a concrete macOS registration API.

## Alternatives considered

| Option | Reason rejected |
| --- | --- |
| Require users to launch CalRelay manually after login | Conflicts with the minimal-effort freshness objective. |
| Run a helper or LaunchAgent while the main app is closed | Adds lifecycle, permission, signing, packaging, rollback, and trust costs before closed-app operation is required. |
| Make the app accessory-only or menu-bar-first | Weakens the recoverable Dock-visible control-panel model and is unnecessary for scheduling. |