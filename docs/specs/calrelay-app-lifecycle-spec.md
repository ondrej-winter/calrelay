# Superseded: CalRelay App Lifecycle and Menu Bar Direction

## Specification record

- **Status:** Superseded on September 14, 2026.
- **Former canonical artifact:** `docs/specs/calrelay-app-lifecycle-spec.md`.
- **Reason:** The accepted control-panel, menu-bar, manual-sync, scheduling, notification, and background-operation requirements are now maintained as one macOS app capability specification. This is a documentation reorganization only; no lifecycle decision changed.

## Canonical replacement

Use [`macos-app-spec.md`](macos-app-spec.md) for all `CalRelay.app` control-surface and lifecycle work. Its closed-app-operation section retains the explicit ADR requirement for launch-at-login, helpers, LaunchAgents, or background sync.

The app must continue to follow the relay, access, and configuration contracts indexed in [`README.md`](README.md).