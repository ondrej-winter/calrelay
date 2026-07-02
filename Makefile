.PHONY: help resolve build test test-xcode lint format format-check check app clean sync-rules require-swift-format require-swiftlint

SWIFT_FORMAT ?= $(shell command -v swift-format 2>/dev/null || xcrun --find swift-format 2>/dev/null || printf '%s' swift-format)
SWIFTLINT ?= $(shell command -v swiftlint 2>/dev/null || test ! -x /opt/homebrew/bin/swiftlint || printf '%s' /opt/homebrew/bin/swiftlint || printf '%s' swiftlint)
XCODE_DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

SWIFT_FORMAT_PATHS := Package.swift Sources Tests
SWIFTLINT_PATHS := Sources Tests Package.swift

help:
	@printf '%s\n' 'CalRelay developer targets:'
	@printf '  %-14s %s\n' 'resolve' 'Resolve Swift package dependencies and update Package.resolved when needed'
	@printf '  %-14s %s\n' 'build' 'Build all SwiftPM products'
	@printf '  %-14s %s\n' 'test' 'Run deterministic SwiftPM tests'
	@printf '  %-14s %s\n' 'test-xcode' 'Run tests with full Xcode selected as DEVELOPER_DIR'
	@printf '  %-14s %s\n' 'format-check' 'Check Swift formatting without modifying files'
	@printf '  %-14s %s\n' 'format' 'Apply Swift formatting in place'
	@printf '  %-14s %s\n' 'lint' 'Run SwiftLint'
	@printf '  %-14s %s\n' 'check' 'Run the local quality gate'
	@printf '  %-14s %s\n' 'app' 'Build the local CalRelay.app bundle'
	@printf '  %-14s %s\n' 'clean' 'Remove SwiftPM build products'
	@printf '  %-14s %s\n' 'sync-rules' 'Sync shared agent and .clinerules assets from the configured upstream'

resolve:
	swift package resolve

build:
	swift build

test:
	swift test

test-xcode:
	DEVELOPER_DIR="$(XCODE_DEVELOPER_DIR)" swift test

format-check: require-swift-format
	$(SWIFT_FORMAT) lint --recursive $(SWIFT_FORMAT_PATHS)

format: require-swift-format
	$(SWIFT_FORMAT) format --recursive --in-place $(SWIFT_FORMAT_PATHS)

lint: require-swiftlint
	DEVELOPER_DIR="$(XCODE_DEVELOPER_DIR)" $(SWIFTLINT) lint --strict --config .swiftlint.yml $(SWIFTLINT_PATHS)

check: lint build test-xcode
	swift run calrelay --help >/dev/null

app:
	zsh scripts/build-calrelay-app.sh

clean:
	swift package clean

sync-rules:
	bash scripts/sync-clinerules.sh

require-swift-format:
	@command -v "$(SWIFT_FORMAT)" >/dev/null 2>&1 || { \
		echo "error: swift-format is required for this target. Install it, make it available through xcrun, or set SWIFT_FORMAT=/path/to/swift-format." >&2; \
		exit 127; \
	}

require-swiftlint:
	@command -v "$(SWIFTLINT)" >/dev/null 2>&1 || { \
		echo "error: SwiftLint is required for this target. Install it or set SWIFTLINT=/path/to/swiftlint." >&2; \
		exit 127; \
	}