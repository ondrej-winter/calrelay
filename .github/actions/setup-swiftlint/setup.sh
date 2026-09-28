#!/bin/bash
set -euo pipefail

cd "$SOURCE_DIRECTORY"
{
  IFS= read -r swiftlint_version
  IFS= read -r swiftlint_asset
  IFS= read -r swiftlint_sha256
} < <(node --input-type=module --eval '
  import { readFileSync } from "node:fs";
  const toolchain = JSON.parse(readFileSync("scripts/release/toolchain.json", "utf8"));
  const swiftLint = toolchain.swiftLint;
  if (
    !swiftLint
    || !/^\d+\.\d+\.\d+$/.test(swiftLint.version ?? "")
    || swiftLint.asset !== "portable_swiftlint.zip"
    || !/^[0-9a-f]{64}$/.test(swiftLint.sha256 ?? "")
  ) {
    throw new Error("release SwiftLint toolchain metadata is invalid");
  }
  process.stdout.write(`${swiftLint.version}\n${swiftLint.asset}\n${swiftLint.sha256}\n`);
')

install_directory="${RUNNER_TEMP}/calrelay-swiftlint"
archive="${RUNNER_TEMP}/${swiftlint_asset}"
trap 'rm -f "$archive"' EXIT
rm -rf "$install_directory" "$archive"
mkdir -p "$install_directory"
curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 --retry 3 \
  --output "$archive" \
  "https://github.com/realm/SwiftLint/releases/download/${swiftlint_version}/${swiftlint_asset}"
printf '%s  %s\n' "$swiftlint_sha256" "$archive" | shasum -a 256 -c -
unzip -q "$archive" -d "$install_directory"

swiftlint_binary="${install_directory}/swiftlint"
[[ -x "$swiftlint_binary" ]] \
  || { echo 'Pinned SwiftLint archive did not contain an executable swiftlint.' >&2; exit 1; }
observed_version="$("$swiftlint_binary" version)"
[[ "$observed_version" == "$swiftlint_version" ]] \
  || { echo "Pinned SwiftLint reported ${observed_version}, expected ${swiftlint_version}." >&2; exit 1; }
printf 'SWIFTLINT=%s\n' "$swiftlint_binary" >> "$GITHUB_ENV"