# 0006. Run CalRelay as a Menu Bar App

Date: 2026-11-06
Status: Accepted
Supersedes: [0001](./0001-launch-normal-app-at-login-for-scheduled-sync.md)

## Context

The project owner wants CalRelay to maintain availability without occupying the
Dock. On November 6, 2026, the owner approved menu bar operation with access to
the existing control panel, persistent operational status, launch-at-login,
continued synchronization after window closure, and synchronization stopping on
Quit. The owner requested a specification update and implementation plan for
review before implementation. The owner subsequently authorized implementation
and local slice commits without pushing; progress and remaining acceptance evidence
are tracked in the implementation plan.

ADR 0001 coupled launch-at-login and in-process scheduling to a Dock-visible
control panel. The same app can retain permission, settings, signing, and
scheduling ownership while moving its persistent entry point to the menu bar.
The product contract is [macOS app specification revision 9](../specs/macos-app-spec.md).

## Decision

Run the existing `CalRelay.app` process as a menu bar app without a Dock icon,
including when its control panel is open. Keep the control panel recoverable
through the menu bar and ordinary explicit launch or reopen, and expose safe
operational status and Quit in the menu bar.

Respect the user's macOS setting to hide the menu bar item, without adding a
competing app preference or changing scheduling. Spotlight and ordinary explicit
launch or reopen retain control-panel and Quit access while the icon is hidden.
The follow-up interview confirmed active problem visibility: for actionable or
overdue problems arising after startup, notify first when notifications are
available; otherwise open the control panel. Do not repeatedly steal focus for
the same unresolved problem. Existing actionable-login presentation still applies.

Retain launch-at-login for this same app and scheduling only while its process
is running. Closing the window leaves synchronization active; Quit stops it
under the existing warning and preference-retention rules. This supersedes ADR
0001 while retaining its decision to avoid separate helpers and execution after
the app exits.

## Consequences

- CalRelay no longer occupies the Dock during ordinary background operation or
  control-panel use. Recovery and exit remain accessible through the menu bar
  when visible and through explicit launch or reopen when the icon is hidden.
- Startup and scheduling ownership must be independent of window presentation.
  A hidden healthy login launch must still initialize and maintain automation.
- Menu bar attention status replaces the Dock badge, subject to the user's
  system visibility setting. Notification-first alerts and the automatic panel
  fallback preserve active recovery when an icon cannot be seen. Accessibility
  and non-color status cues still matter whenever the item is visible.
- The production bundle identifier, Developer Team identity, Calendar permission
  ownership, persistence, standing-authorization bindings, and launch-at-login
  identity remain stable. There is no new service, entitlement, or data migration
  required by this decision.
- Crashes and Quit still stop scheduling. A menu bar app is a running app, not
  authorization for synchronization after its process exits.
- App packaging, window recovery, hidden startup, UI automation, and manual
  macOS lifecycle checks need validation before delivery. The implementation
  strategy and evidence belong in the [implementation plan](../plans/menu-bar-app-implementation-plan.md).

## Alternatives considered

| Option                                                           | Reason rejected                                                                                            |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Retain the Dock-visible shell with a hidden window               | Still occupies the Dock and does not meet the owner's preference.                                          |
| Run a separate helper or LaunchAgent                             | Adds lifecycle and permission complexity when the requirement is continued operation with a closed window. |
| Provide a background process without a persistent UI entry point | Makes setup, permission recovery, status, and intentional Quit harder to discover.                         |
