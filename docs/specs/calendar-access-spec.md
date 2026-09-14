# Spec: Calendar Access

## Specification record

- **Status:** Accepted.
- **Revision:** 1 — split from the accepted EventKit MVP specification on September 14, 2026; behavior is unchanged.
- **Canonical artifact:** `docs/specs/calendar-access-spec.md`.
- **Scope:** Calendar permission, discovery, writability, and EventKit boundary behavior.

## Required outcomes

### ACCESS-01 — Permission and discovery

- Request Calendar permission at the platform boundary.
- List available calendars, sources/accounts, and writable/read-only status.
- Fail safely when Calendar permission is unavailable, denied, or revoked, or when a target calendar is read-only.
- Calendar IDs may be displayed for troubleshooting but are not the canonical configuration key.

### ACCESS-02 — EventKit boundary

- EventKit types, calendar IDs, calendar stores, permission APIs, and mutation mechanics remain in adapters or app/bootstrap code.
- Map EventKit types into application DTOs at the adapter boundary.
- Mutate only calendars configured for the current run and only when they are writable.

## Validation

- The calendar capability command lists calendars, sources/accounts, and writability.
- Real EventKit capability checks are explicit local validation through `CalRelay.app` or the CLI; default deterministic tests do not require real EventKit access.
- Manually validate Calendar permission with the stable `CalRelay.app` bundle identity.

## Acceptance checks

- **ACCESS-AC-01:** Permission failures and read-only targets fail before unsafe mutation.
- **ACCESS-AC-02:** Deterministic core tests run without EventKit access or EventKit types in domain/application APIs.

## Constraints

- Do not pass EventKit types into domain/application APIs.
- Do not rely on live external provider APIs in default tests.
- Direct provider APIs, OAuth, app registrations, tenant approvals, and provider-specific sync tokens are excluded.