#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-debug}"
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

swift build --product "${EXECUTABLE_NAME}" -c "${CONFIGURATION}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${EXECUTABLE_NAME}" "${MACOS_DIR}/${EXECUTABLE_NAME}"
cp "${ROOT_DIR}/Resources/CalRelayApp/Info.plist" "${CONTENTS_DIR}/Info.plist"
chmod 755 "${MACOS_DIR}/${EXECUTABLE_NAME}"

/usr/bin/xattr -cr "${APP_BUNDLE}"
/usr/bin/codesign --force --sign - "${APP_BUNDLE}"
/usr/bin/xattr -cr "${APP_BUNDLE}"
/usr/bin/codesign --verify --deep --strict "${APP_BUNDLE}"

echo "Built ${APP_BUNDLE}"
rm -rf "${APP_LINK}"
ln -s "${APP_BUNDLE}" "${APP_LINK}"
echo "Open with: open '${APP_LINK}'"