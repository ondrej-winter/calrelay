#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_NAME="CalRelay"
EXECUTABLE_NAME="CalRelayApp"
BUILD_DIR="${ROOT_DIR}/.build/${CONFIGURATION}"
APP_BUNDLE="${ROOT_DIR}/.build/${APP_NAME}.app"
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

/usr/bin/codesign --force --sign - "${APP_BUNDLE}"

echo "Built ${APP_BUNDLE}"
echo "Open with: open '${APP_BUNDLE}'"