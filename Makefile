.PHONY: help resolve build test ui-test lint format format-check check app commit clean require-swift-format require-swiftlint

SWIFT_FORMAT ?= $(shell command -v swift-format 2>/dev/null || xcrun --find swift-format 2>/dev/null || printf '%s' swift-format)
SWIFTLINT ?= $(shell command -v swiftlint 2>/dev/null || test ! -x /opt/homebrew/bin/swiftlint || printf '%s' /opt/homebrew/bin/swiftlint || printf '%s' swiftlint)
XCODE_DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
UI_TEST_WORKSPACE_KEY := $(shell printf '%s' "$(CURDIR)" | /usr/bin/shasum -a 256 | /usr/bin/cut -d ' ' -f 1)
UI_TEST_DERIVED_DATA ?= $(HOME)/Library/Caches/dev.owinter.CalRelay/xcode-ui-tests/$(UI_TEST_WORKSPACE_KEY)
UI_TEST_RESULT_BUNDLE ?= $(CURDIR)/.build/CalRelayUITests.xcresult

SWIFT_FORMAT_PATHS := Package.swift Sources Tests UITests
SWIFTLINT_PATHS := Sources Tests UITests Package.swift

help:
	@printf '%s\n' 'CalRelay developer targets:'
	@printf '  %-14s %s\n' 'resolve' 'Resolve Swift package dependencies and update Package.resolved when needed'
	@printf '  %-14s %s\n' 'build' 'Build all SwiftPM products'
	@printf '  %-14s %s\n' 'test' 'Run deterministic SwiftPM tests'
	@printf '  %-14s %s\n' 'ui-test' 'Run fake-backed macOS UI smoke tests'
	@printf '  %-14s %s\n' 'format-check' 'Check Swift formatting without modifying files'
	@printf '  %-14s %s\n' 'format' 'Apply Swift formatting in place'
	@printf '  %-14s %s\n' 'lint' 'Run SwiftLint'
	@printf '  %-14s %s\n' 'check' 'Run the local quality gate'
	@printf '  %-14s %s\n' 'app' 'Build the local CalRelay.app bundle'
	@printf '  %-14s %s\n' 'commit' 'Create a Conventional Commit with Fabrica'
	@printf '  %-14s %s\n' 'clean' 'Remove SwiftPM build products'

resolve:
	swift package resolve

build:
	swift build

test:
	swift run CalRelayKitTests

ui-test:
	zsh scripts/build-calrelay-ui-test-app.sh
	rm -rf "$(UI_TEST_RESULT_BUNDLE)"
	DEVELOPER_DIR="$(XCODE_DEVELOPER_DIR)" /usr/bin/xcodebuild test \
		-project CalRelayUITests.xcodeproj \
		-scheme CalRelayUITests \
		-destination 'platform=macOS' \
		-derivedDataPath "$(UI_TEST_DERIVED_DATA)" \
		-resultBundlePath "$(UI_TEST_RESULT_BUNDLE)"

format-check: require-swift-format
	$(SWIFT_FORMAT) lint --recursive $(SWIFT_FORMAT_PATHS)

format: require-swift-format
	$(SWIFT_FORMAT) format --recursive --in-place $(SWIFT_FORMAT_PATHS)

lint: require-swiftlint
	DEVELOPER_DIR="$(XCODE_DEVELOPER_DIR)" $(SWIFTLINT) lint --strict --config .swiftlint.yml $(SWIFTLINT_PATHS)

check: lint build test
	swift run calrelay --help >/dev/null

app:
	zsh scripts/build-calrelay-app.sh

commit:
	uvx fabrica commit \
		--skill conventional-commits \
		--skill-root .agents/skills \
		--model gpt-5.6-luna \
		--reasoning-effort low

clean:
	swift package clean

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