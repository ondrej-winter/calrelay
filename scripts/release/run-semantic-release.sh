#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h:h}"
TOOLCHAIN="${ROOT_DIR}/scripts/release/toolchain.json"
NODE_VERSION="$(node -e 'const data = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8")); process.stdout.write(data.node);' "${TOOLCHAIN}")"
SEMANTIC_RELEASE_VERSION="$(node -e 'const data = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8")); process.stdout.write(data.semanticRelease);' "${TOOLCHAIN}")"

if [[ "$(node --version)" != "v${NODE_VERSION}" ]]; then
    echo "error: release automation requires Node ${NODE_VERSION}." >&2
    exit 1
fi

cd "${ROOT_DIR}"

bootstrap=0
semantic_release_arguments=()
for argument in "$@"; do
    if [[ "${argument}" == "--bootstrap" ]]; then
        bootstrap=1
    else
        semantic_release_arguments+=("${argument}")
    fi
done

if (( bootstrap )); then
    export CALRELAY_RELEASE_BOOTSTRAP=1
else
    unset CALRELAY_RELEASE_BOOTSTRAP
fi

exec npx --yes --package "semantic-release@${SEMANTIC_RELEASE_VERSION}" semantic-release "${semantic_release_arguments[@]}"