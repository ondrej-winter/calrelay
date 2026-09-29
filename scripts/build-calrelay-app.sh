#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-debug}"
VERSION_FILE="${ROOT_DIR}/VERSION"
ENTITLEMENTS_FILE="${ROOT_DIR}/Resources/CalRelayApp/CalRelayApp.entitlements"
APP_NAME="CalRelay"
EXECUTABLE_NAME="CalRelayApp"
BUILD_DIR="${ROOT_DIR}/.build/${CONFIGURATION}"
WORKSPACE_KEY="$(printf '%s' "${ROOT_DIR}" | /usr/bin/shasum -a 256 | /usr/bin/cut -d ' ' -f 1)"
# File-provider workspaces can reattach FinderInfo while codesign is running.
# Keep the signed bundle outside that tree, with the familiar local launch path.
BUNDLE_DIR="${HOME}/Library/Caches/dev.owinter.CalRelay/builds/${WORKSPACE_KEY}"
APP_BUNDLE="${BUNDLE_DIR}/${APP_NAME}.app"
APP_LINK="${ROOT_DIR}/.build/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

cd "${ROOT_DIR}"

if [[ ! -f "${VERSION_FILE}" ]]; then
    echo "error: VERSION is missing at ${VERSION_FILE}." >&2
    exit 1
fi

RELEASE_VERSION="$(/bin/cat "${VERSION_FILE}")"
if ! printf '%s' "${RELEASE_VERSION}" | /usr/bin/cmp -s - "${VERSION_FILE}" \
    || [[ "${RELEASE_VERSION}" == *$'\n'* ]] \
    || ! printf '%s\n' "${RELEASE_VERSION}" \
        | /usr/bin/grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'; then
    echo "error: VERSION must contain exactly one canonical X.Y.Z value without surrounding content." >&2
    exit 1
fi

# Apple compares CFBundleVersion as up to three period-separated integers. Using
# the canonical release version directly is deterministic and monotonic for every
# permitted later semantic-version transition.
BUNDLE_VERSION="${RELEASE_VERSION}"

swift build --product "${EXECUTABLE_NAME}" -c "${CONFIGURATION}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${EXECUTABLE_NAME}" "${MACOS_DIR}/${EXECUTABLE_NAME}"
cp "${ROOT_DIR}/Resources/CalRelayApp/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${ROOT_DIR}/Resources/CalRelayApp/CalRelay.icns" "${RESOURCES_DIR}/CalRelay.icns"

INFO_PLIST="${CONTENTS_DIR}/Info.plist"
/usr/bin/plutil -lint "${INFO_PLIST}" >/dev/null
/usr/bin/plutil -replace CFBundleShortVersionString -string "${RELEASE_VERSION}" "${INFO_PLIST}"
/usr/bin/plutil -replace CFBundleVersion -string "${BUNDLE_VERSION}" "${INFO_PLIST}"
for key in NSCalendarsFullAccessUsageDescription NSCalendarsUsageDescription; do
    if ! value=$(/usr/bin/plutil -extract "${key}" raw -expect string "${INFO_PLIST}" 2>/dev/null) || [[ -z "${value//[[:space:]]/}" ]]; then
        echo "error: ${key} must be a nonempty string in ${INFO_PLIST}." >&2
        exit 1
    fi
done
if [[ "$(/usr/bin/plutil -extract com\\.apple\\.security\\.personal-information\\.calendars raw -expect bool "${ENTITLEMENTS_FILE}" 2>/dev/null)" != true ]]; then
    echo "error: ${ENTITLEMENTS_FILE} must grant read/write Calendar access." >&2
    exit 1
fi
if /usr/bin/plutil -extract com\\.apple\\.security\\.app-sandbox raw "${ENTITLEMENTS_FILE}" >/dev/null 2>&1; then
    echo "error: the local CalRelay app must remain unsandboxed." >&2
    exit 1
fi

chmod 755 "${MACOS_DIR}/${EXECUTABLE_NAME}"

/usr/bin/xattr -cr "${APP_BUNDLE}"
/usr/bin/codesign --force --sign - --entitlements "${ENTITLEMENTS_FILE}" "${APP_BUNDLE}"
/usr/bin/xattr -cr "${APP_BUNDLE}"
/usr/bin/codesign --verify --deep --strict "${APP_BUNDLE}"
SIGNED_ENTITLEMENTS="$(/usr/bin/codesign -d --entitlements :- "${APP_BUNDLE}" 2>/dev/null)"
if [[ "$(printf %s "${SIGNED_ENTITLEMENTS}" | /usr/bin/plutil -extract com\\.apple\\.security\\.personal-information\\.calendars raw -expect bool -o - - 2>/dev/null)" != true ]]; then
    echo "error: the signed local CalRelay app is missing read/write Calendar access." >&2
    exit 1
fi

echo "Built ${APP_BUNDLE}"
rm -rf "${APP_LINK}"
ln -s "${APP_BUNDLE}" "${APP_LINK}"
echo "Open with: open '${APP_LINK}'"