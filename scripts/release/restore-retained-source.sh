#!/bin/zsh
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo 'usage: restore-retained-source.sh <candidate-directory> <release-commit> <release-tag>' >&2
  exit 64
fi

candidate_directory="$1"
release_commit="$2"
release_tag="$3"
state="${candidate_directory}/release-state.json"
bundle="${candidate_directory}/source.bundle"

[[ "$release_commit" =~ '^[0-9a-f]{40}$' ]] || { echo 'Release commit must be a full lowercase Git revision.' >&2; exit 1; }
[[ "$release_tag" =~ '^v1\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' ]] || { echo 'Release tag must be a canonical v1.x tag.' >&2; exit 1; }
[[ -f "$state" ]] || { echo 'Retained release state is missing.' >&2; exit 1; }
[[ -f "$bundle" ]] || { echo 'Retained source bundle is missing.' >&2; exit 1; }

node --input-type=module --eval '
  import { createHash } from "node:crypto";
  import { readFileSync } from "node:fs";
  const [statePath, bundlePath] = process.argv.slice(1);
  const state = JSON.parse(readFileSync(statePath, "utf8"));
  const observed = createHash("sha256").update(readFileSync(bundlePath)).digest("hex");
  if (state.sourceBundle?.name !== "source.bundle" || state.sourceBundle.sha256 !== observed) {
    throw new Error("retained source bundle digest conflicts with release state");
  }
' "$state" "$bundle"

git bundle verify "$bundle" >/dev/null 2>&1 || { echo 'Retained source bundle failed Git verification.' >&2; exit 1; }
git fetch --quiet --no-tags "$bundle" refs/heads/master:refs/remotes/calrelay-candidate/master
git fetch --quiet --no-tags "$bundle" "refs/tags/${release_tag}:refs/tags/${release_tag}"
[[ "$(git rev-parse refs/remotes/calrelay-candidate/master)" == "$release_commit" ]] \
  || { echo 'Retained source branch does not match the release commit.' >&2; exit 1; }
[[ "$(git rev-parse "refs/tags/${release_tag}")" == "$release_commit" ]] \
  || { echo 'Retained source tag does not match the release commit.' >&2; exit 1; }
git checkout --quiet --detach "$release_commit"
cat VERSION