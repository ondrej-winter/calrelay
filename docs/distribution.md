# CalRelay public-beta distribution

> **Availability:** As of September 28, 2026, the public channel is not live. The
> `v1.0.0` bootstrap and protected production validation remain pending. The
> commands below are the accepted installation interface to use after that
> bootstrap is published.

CalRelay's public beta supports Apple Silicon Macs running macOS 26 or later. The
CLI and app are separate Homebrew packages with the same `calrelay` token. They
may be installed independently or together, and Homebrew owns their upgrades.

## Install

### CLI only

```sh
brew install ondrej-winter/tap/calrelay
```

This installs the prebuilt `calrelay` executable. Installation does not invoke
SwiftPM, launch CalRelay, read configuration, access calendars, or request
Calendar permission. In short, installation does not request Calendar permission.

### App only

```sh
brew install --cask ondrej-winter/tap/calrelay
```

This installs the prebuilt, signed, and notarized `CalRelay.app`. Installation
does not launch the app or request Calendar permission.

### Install both

Run both supported commands above. The formula owns only the CLI and the cask
owns only the app, so either installation order is supported.

The upstream `ondrej-winter/tap` channel remains authoritative throughout the
public beta. Promotion to another Homebrew channel requires a later accepted and
documented migration.

## Configuration and Calendar access

Both products use the canonical configuration file:

```text
~/.config/calrelay/config.yaml
```

See [CalRelay configuration](configuration.md) for the schema and safe setup
workflow. Installation, upgrade, and ordinary uninstallation do not create,
rewrite, or remove this file or alternate user-created configuration files.

CLI commands inspect Calendar authorization but do not request it. Open
`CalRelay.app` intentionally when setup or recovery is needed. The app reports
current access first; use the setup or recovery action to ask macOS for full
Calendar access. Merely installing or upgrading the app never performs that
request and never starts reconciliation.

## Upgrade

Upgrade the installed package or packages independently:

```sh
brew upgrade ondrej-winter/tap/calrelay
brew upgrade --cask ondrej-winter/tap/calrelay
```

A formula upgrade replaces only the CLI. A cask upgrade replaces only the app,
retains the stable app identity, and does not automatically launch it. Compatible
app state is retained; if launch-at-login needs attention after an app upgrade,
the existing control-panel recovery state reports it when CalRelay runs.

## Ordinary uninstallation

Remove either package independently:

```sh
brew uninstall ondrej-winter/tap/calrelay
brew uninstall --cask ondrej-winter/tap/calrelay
```

The formula removal leaves the app installed, and the cask removal leaves the
CLI installed. In both cases, ordinary uninstallation retains
`~/.config/calrelay/config.yaml`, alternate configurations, compatible app state
retained by macOS, Calendar permissions, calendar events, and unrelated files.
Uninstallation does not launch a product or mutate calendars. The public-beta
cask provides no destructive `zap` operation.

Reinstalling later uses the same canonical configuration location.

## Verify an installed copy

The CLI can be checked without configuration or Calendar access:

```sh
calrelay --version
calrelay --help
```

For app signature, notarization, and Gatekeeper evidence, release operators use
the protected release gate described in [Release operations](release-operations.md).