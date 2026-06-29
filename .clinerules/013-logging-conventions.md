# Logging conventions

Use these rules to keep logging consistent, searchable, privacy-safe, and easy to filter across modules.

This file covers logging implementation details. Broader code quality expectations live in `002-core-standards.md`. Secret source handling and configuration boundaries live in `008-configuration-and-secrets.md`.

## Default logger pattern

- **Should** use Apple's `Logger` from `os` for macOS app logs when no project-specific logging stack is configured.
- **Must** define loggers close to the component that emits logs, with stable subsystem and category names.
- **Should** use one logger per file, adapter, or focused component rather than creating ad hoc loggers inside every function.
- **Must not** duplicate global logging setup in feature modules.

Example:

```swift
import os

private let logger = Logger(subsystem: "<bundle_identifier>", category: "InvoiceCapture")
```

## Message construction and levels

- **Should** choose log levels based on operational usefulness: `debug` for diagnostics, `info` for state transitions, `notice` for important normal events, `warning` for recoverable anomalies, and `error` or `fault` for user-visible or operator-visible failures.
- **Should** prefer concise, event-oriented messages with structured interpolation over dumping raw payloads into the message body.
- **Should** keep messages stable and searchable. Put variable details in structured fields when possible.
- **Must** use privacy annotations deliberately for interpolated values when using `Logger`.

## Privacy and sensitive data

- **Must not** log secrets, tokens, passwords, cookies, authentication headers, private keys, signing credentials, raw request/response bodies, file contents, personal data, or user document contents unless there is an explicit approved diagnostic need.
- **Must** mark private values as private when using unified logging interpolation.
- **Should** prefer allowlisted metadata such as counts, sizes, status codes, durations, operation IDs, and coarse categories over raw content.
- **Must** avoid full file paths, raw search queries, email addresses, and unique user identifiers unless approved and privacy-reviewed.

## Context and structure

- **Should** include stable context for recurring concepts such as operation ID, feature, adapter, document ID, request ID, or sync ID when safe.
- **Should** propagate correlation or operation IDs across adapter boundaries when available.
- **Must not** put secrets or very high-cardinality raw values into structured fields by default.
- **Should** keep subsystem and category values stable so Console filtering and diagnostics remain useful.

## Volume management

- **Should** sample, aggregate, or rate-limit repeated noisy logs in retry loops, polling loops, file watchers, notification handlers, and hot paths.
- **Should** log outcomes at meaningful boundaries rather than every low-level step when high-volume logging would hide signal.
- **Should** use signposts for profiling high-volume timing data instead of noisy ordinary logs.

## Exception and error logging

- **Should** log an error once at the boundary that can handle, translate, or report it.
- **Must** avoid duplicate full-error logging at multiple layers for the same failure.
- **Should** include safe context and recovery action when logging user-visible failures.

## Central configuration

- **Must** configure logging and diagnostics through central app/bootstrap utilities when custom configuration exists.
- **Must** keep production logging privacy-safe by default.
