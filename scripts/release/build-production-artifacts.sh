#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h:h}"
VERSION_FILE="${ROOT_DIR}/VERSION"
OUTPUT_DIR="${CALRELAY_RELEASE_OUTPUT_DIR:-${ROOT_DIR}/.build/release-artifacts}"
WORK_DIR="${OUTPUT_DIR}/.work"
SECRETS_DIR="${WORK_DIR}/secrets"
CLI_DIR="${WORK_DIR}/cli"
APP_BUNDLE="${WORK_DIR}/CalRelay.app"
APP_ENTITLEMENTS="${ROOT_DIR}/Resources/CalRelayApp/CalRelayApp.entitlements"
KEYCHAIN_PATH="${WORK_DIR}/calrelay-release.keychain-db"
KEYCHAIN_PASSWORD="calrelay-$(/usr/bin/uuidgen)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

for name in CALRELAY_DEVELOPER_ID_P12 CALRELAY_DEVELOPER_ID_P12_PASSWORD CALRELAY_NOTARY_API_KEY_P8 CALRELAY_NOTARY_KEY_ID CALRELAY_NOTARY_ISSUER_ID CALRELAY_DEVELOPER_TEAM_ID CALRELAY_SIGNING_CERTIFICATE_SHA1; do
    if [[ -z "${(P)name:-}" ]]; then
        print -u2 -- "error: ${name} is required for production artifact packaging."
        exit 1
    fi
done
if ! print -r -- "${CALRELAY_SIGNING_CERTIFICATE_SHA1}" | /usr/bin/grep -Eq "^[0-9A-Fa-f]{40}$"; then
    print -u2 -- "error: CALRELAY_SIGNING_CERTIFICATE_SHA1 must contain exactly 40 hexadecimal characters."
    exit 1
fi
SIGNING_CERTIFICATE_SHA1="${CALRELAY_SIGNING_CERTIFICATE_SHA1:u}"
if [[ ! -f "${VERSION_FILE}" ]]; then
    print -u2 -- "error: VERSION is missing at ${VERSION_FILE}."
    exit 1
fi
RELEASE_VERSION="$(/bin/cat "${VERSION_FILE}")"
if ! print -rn -- "${RELEASE_VERSION}" | /usr/bin/cmp -s - "${VERSION_FILE}" || ! print -r -- "${RELEASE_VERSION}" | /usr/bin/grep -Eq "^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"; then
    print -u2 -- "error: VERSION must contain exactly one canonical X.Y.Z value without surrounding content."
    exit 1
fi

if [[ "${CALRELAY_RELEASE_TESTING:-0}" == 1 ]]; then
    TOOLS="${CALRELAY_RELEASE_TEST_TOOLS_DIR:?CALRELAY_RELEASE_TEST_TOOLS_DIR is required in test mode}"
    XCODEBUILD="${TOOLS}/xcodebuild"
    SW_VERS="${TOOLS}/sw_vers"
    UNAME="${TOOLS}/uname"
    SWIFT="${TOOLS}/swift"
    SECURITY="${TOOLS}/security"
    CODESIGN="${TOOLS}/codesign"
    LIPO="${TOOLS}/lipo"
    VTOOL="${TOOLS}/vtool"
    NOTARYTOOL="${TOOLS}/notarytool"
    STAPLER="${TOOLS}/stapler"
    SPCTL="${TOOLS}/spctl"
    SDK_PATH="${TOOLS}/MacOSX27.0.sdk"
    SDK_VERSION="27.0"
else
    XCODEBUILD=/usr/bin/xcodebuild
    SW_VERS=/usr/bin/sw_vers
    UNAME=/usr/bin/uname
    SWIFT="$(/usr/bin/xcrun --find swift)"
    SECURITY=/usr/bin/security
    CODESIGN=/usr/bin/codesign
    LIPO="$(/usr/bin/xcrun --find lipo)"
    VTOOL="$(/usr/bin/xcrun --find vtool)"
    NOTARYTOOL="$(/usr/bin/xcrun --find notarytool)"
    STAPLER="$(/usr/bin/xcrun --find stapler)"
    SPCTL=/usr/sbin/spctl
    SDK_PATH="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
    SDK_VERSION="$(/usr/bin/xcrun --sdk macosx --show-sdk-version)"
fi

XCODE_VERSION="$("${XCODEBUILD}" -version)"
SWIFT_VERSION="$("${SWIFT}" --version 2>&1)"
RUNNER_ARCH="$("${UNAME}" -m)"
RUNNER_MACOS="$("${SW_VERS}" -productVersion)"
if [[ "${XCODE_VERSION}" != Xcode\ 27.* ]]; then
    print -u2 -- "error: production packaging requires Xcode 27."
    exit 1
fi
if [[ "${SWIFT_VERSION}" != *"Swift version 6.4"* ]]; then
    print -u2 -- "error: production packaging requires Swift 6.4."
    exit 1
fi
if [[ "${SDK_VERSION}" != 27.* ]]; then
    print -u2 -- "error: production packaging requires the macOS 27 SDK."
    exit 1
fi
if [[ "${RUNNER_ARCH}" != arm64 ]]; then
    print -u2 -- "error: production packaging requires an Apple Silicon runner."
    exit 1
fi
if [[ "${RUNNER_MACOS%%.*}" -lt 27 ]]; then
    print -u2 -- "error: production packaging requires macOS 27 or later."
    exit 1
fi
if ! /usr/bin/grep -Fq "// swift-tools-version: 6.4" "${ROOT_DIR}/Package.swift" || ! /usr/bin/grep -Fq "platforms: [.macOS(.v26)]" "${ROOT_DIR}/Package.swift"; then
    print -u2 -- "error: Package.swift must retain Swift tools 6.4 and macOS 26 deployment."
    exit 1
fi

KEYCHAIN_CREATED=0
FINAL_OUTPUTS_OWNED=0
FINAL_OUTPUTS_COMPLETE=0
CLI_BUILD_PRODUCT="${ROOT_DIR}/.build/release/calrelay"
APP_BUILD_PRODUCT="${ROOT_DIR}/.build/release/CalRelayApp"
BUILD_PRODUCTS_OWNED=0
cleanup() {
    local exit_code=$?
    if (( KEYCHAIN_CREATED )); then
        "${SECURITY}" delete-keychain "${KEYCHAIN_PATH}" >/dev/null 2>&1 || true
        KEYCHAIN_CREATED=0
    fi
    if (( FINAL_OUTPUTS_OWNED && ! FINAL_OUTPUTS_COMPLETE )); then
        /bin/rm -f "${CLI_ARCHIVE}" "${APP_ARCHIVE}" "${MANIFEST}"
    fi
    if (( BUILD_PRODUCTS_OWNED )); then
        /bin/rm -f "${CLI_BUILD_PRODUCT}" "${APP_BUILD_PRODUCT}"
    fi
    /bin/rm -rf "${WORK_DIR}"
    return "${exit_code}"
}
trap cleanup EXIT ZERR INT TERM HUP

/bin/rm -rf "${WORK_DIR}"
/bin/mkdir -p "${SECRETS_DIR}" "${CLI_DIR}" "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources" "${OUTPUT_DIR}"
/bin/chmod 700 "${SECRETS_DIR}"
print -rn -- "${CALRELAY_DEVELOPER_ID_P12}" | /usr/bin/base64 -D > "${SECRETS_DIR}/developer-id.p12"
print -rn -- "${CALRELAY_NOTARY_API_KEY_P8}" > "${SECRETS_DIR}/notary-key.p8"
/bin/chmod 600 "${SECRETS_DIR}/developer-id.p12" "${SECRETS_DIR}/notary-key.p8"
"${SECURITY}" create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}" >/dev/null
KEYCHAIN_CREATED=1
"${SECURITY}" set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}" >/dev/null
"${SECURITY}" unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}" >/dev/null
"${SECURITY}" import "${SECRETS_DIR}/developer-id.p12" -k "${KEYCHAIN_PATH}" -P "${CALRELAY_DEVELOPER_ID_P12_PASSWORD}" -T /usr/bin/codesign >/dev/null
"${SECURITY}" set-key-partition-list -S apple-tool:,apple: -s -k "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}" >/dev/null
SIGNING_IDENTITIES="$("${SECURITY}" find-identity -v -p codesigning "${KEYCHAIN_PATH}")"
MATCHING_IDENTITY_COUNT="$(print -r -- "${SIGNING_IDENTITIES}" | /usr/bin/grep -Eic "^[[:space:]]*[0-9]+\)[[:space:]]+${SIGNING_CERTIFICATE_SHA1}[[:space:]]+\"Developer ID Application:" || true)"
if [[ "${MATCHING_IDENTITY_COUNT}" != 1 ]]; then
    print -u2 -- "error: the ephemeral keychain does not contain exactly one valid expected Developer ID Application signing certificate."
    exit 1
fi

cd "${ROOT_DIR}"
/bin/rm -f "${CLI_BUILD_PRODUCT}" "${APP_BUILD_PRODUCT}"
BUILD_PRODUCTS_OWNED=1
MACOSX_DEPLOYMENT_TARGET=26.0 "${SWIFT}" build --sdk "${SDK_PATH}" -c release --arch arm64 --product calrelay
MACOSX_DEPLOYMENT_TARGET=26.0 "${SWIFT}" build --sdk "${SDK_PATH}" -c release --arch arm64 --product CalRelayApp
/bin/cp "${CLI_BUILD_PRODUCT}" "${CLI_DIR}/calrelay"
/bin/cp "${APP_BUILD_PRODUCT}" "${APP_BUNDLE}/Contents/MacOS/CalRelayApp"
/bin/cp "${ROOT_DIR}/Resources/CalRelayApp/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleShortVersionString -string "${RELEASE_VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "${RELEASE_VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
/bin/chmod 755 "${CLI_DIR}/calrelay" "${APP_BUNDLE}/Contents/MacOS/CalRelayApp"
/usr/bin/xattr -cr "${CLI_DIR}/calrelay" "${APP_BUNDLE}"

sign_and_verify() {
    local target="$1"
    local entitlements="${2:-}"
    if [[ -n "${entitlements}" ]]; then
        "${CODESIGN}" --force --options runtime --timestamp --sign "${SIGNING_CERTIFICATE_SHA1}" --keychain "${KEYCHAIN_PATH}" --entitlements "${entitlements}" "${target}"
    else
        "${CODESIGN}" --force --options runtime --timestamp --sign "${SIGNING_CERTIFICATE_SHA1}" --keychain "${KEYCHAIN_PATH}" "${target}"
    fi
    "${CODESIGN}" --verify --strict --verbose=2 "${target}"
    local metadata="$("${CODESIGN}" -dv --verbose=4 "${target}" 2>&1)"
    if [[ "${metadata}" != *"TeamIdentifier=${CALRELAY_DEVELOPER_TEAM_ID}"* || "${metadata}" != *runtime* || "${metadata}" != *Timestamp=* ]]; then
        print -u2 -- "error: signed product identity, hardened runtime, or secure timestamp verification failed."
        return 1
    fi
}
verify_binary() {
    local binary="$1"
    if [[ "$("${LIPO}" -archs "${binary}")" != arm64 ]]; then
        print -u2 -- "error: release products must contain only arm64 architecture."
        return 1
    fi
    local metadata="$("${VTOOL}" -show-build "${binary}")"
    if ! print -r -- "${metadata}" | /usr/bin/grep -Eq "^[[:space:]]*platform[[:space:]]+MACOS[[:space:]]*$" || ! print -r -- "${metadata}" | /usr/bin/grep -Eq "^[[:space:]]*minos[[:space:]]+26\.0[[:space:]]*$"; then
        print -u2 -- "error: release products must be macOS binaries with macOS 26 as the minimum deployment target."
        return 1
    fi
}
sign_and_verify "${CLI_DIR}/calrelay"
sign_and_verify "${APP_BUNDLE}" "${APP_ENTITLEMENTS}"
verify_binary "${CLI_DIR}/calrelay"
verify_binary "${APP_BUNDLE}/Contents/MacOS/CalRelayApp"

INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"
for expected in "CFBundleIdentifier:dev.owinter.CalRelay" "CFBundleExecutable:CalRelayApp" "CFBundleShortVersionString:${RELEASE_VERSION}" "CFBundleVersion:${RELEASE_VERSION}" "LSMinimumSystemVersion:26.0"; do
    key="${expected%%:*}"
    value="${expected#*:}"
    if [[ "$(/usr/bin/plutil -extract "${key}" raw "${INFO_PLIST}")" != "${value}" ]]; then
        print -u2 -- "error: production app metadata mismatch for ${key}."
        exit 1
    fi
done
APP_EFFECTIVE_ENTITLEMENTS="$("${CODESIGN}" -d --entitlements :- "${APP_BUNDLE}" 2>/dev/null)"
if [[ "$(print -rn -- "${APP_EFFECTIVE_ENTITLEMENTS}" | /usr/bin/plutil -extract com\\.apple\\.security\\.personal-information\\.calendars raw -expect bool -o - - 2>/dev/null)" != true ]]; then
    print -u2 -- "error: the production app must include read/write Calendar access."
    exit 1
fi
if print -rn -- "${APP_EFFECTIVE_ENTITLEMENTS}" | /usr/bin/grep -Fq "com.apple.security.app-sandbox"; then
    print -u2 -- "error: the production app must remain unsandboxed."
    exit 1
fi

notarize() {
    local container="$1"
    local result="$2"
    "${NOTARYTOOL}" submit "${container}" --key "${SECRETS_DIR}/notary-key.p8" --key-id "${CALRELAY_NOTARY_KEY_ID}" --issuer "${CALRELAY_NOTARY_ISSUER_ID}" --wait --output-format json > "${result}"
    if ! /usr/bin/grep -Eq "\"status\"[[:space:]]*:[[:space:]]*\"Accepted\"" "${result}"; then
        print -u2 -- "error: Apple notarization did not accept a release product."
        return 1
    fi
}
CLI_NOTARY="${WORK_DIR}/calrelay-notary.zip"
APP_NOTARY="${WORK_DIR}/CalRelay-notary.zip"
COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --keepParent "${CLI_DIR}/calrelay" "${CLI_NOTARY}"
notarize "${CLI_NOTARY}" "${WORK_DIR}/cli-notary.json"
COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --keepParent "${APP_BUNDLE}" "${APP_NOTARY}"
notarize "${APP_NOTARY}" "${WORK_DIR}/app-notary.json"
"${STAPLER}" staple "${APP_BUNDLE}"
"${STAPLER}" validate "${APP_BUNDLE}"
"${CODESIGN}" --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
"${SPCTL}" --assess --type execute --verbose=4 "${APP_BUNDLE}"
if [[ "$("${CLI_DIR}/calrelay" --version)" != "${RELEASE_VERSION}" ]]; then
    print -u2 -- "error: packaged CLI version does not match VERSION."
    exit 1
fi
"${CLI_DIR}/calrelay" --help >/dev/null

CLI_ARCHIVE="${OUTPUT_DIR}/calrelay-${RELEASE_VERSION}-arm64.tar.gz"
APP_ARCHIVE="${OUTPUT_DIR}/CalRelay-${RELEASE_VERSION}-arm64.zip"
MANIFEST="${OUTPUT_DIR}/candidate-manifest.json"
if [[ -e "${CLI_ARCHIVE}" || -e "${APP_ARCHIVE}" || -e "${MANIFEST}" ]]; then
    print -u2 -- "error: refusing to replace existing immutable release artifacts."
    exit 1
fi

scan_value() {
    local value="$1"
    [[ -z "${value}" ]] && return 0
    if /usr/bin/grep -R -a -F -q -- "${value}" "${CLI_DIR}" "${APP_BUNDLE}"; then
        print -u2 -- "error: generated products contain prohibited sensitive release data."
        return 1
    fi
}
scan_value "${CALRELAY_DEVELOPER_ID_P12_PASSWORD}"
scan_value "${CALRELAY_NOTARY_API_KEY_P8}"
if [[ -n "${CALRELAY_RELEASE_PROHIBITED_SENTINELS:-}" ]]; then
    while IFS= read -r sentinel; do scan_value "${sentinel}"; done <<< "${CALRELAY_RELEASE_PROHIBITED_SENTINELS}"
fi
STAGED_CLI_ARCHIVE="${WORK_DIR}/${CLI_ARCHIVE:t}"
STAGED_APP_ARCHIVE="${WORK_DIR}/${APP_ARCHIVE:t}"
STAGED_MANIFEST="${WORK_DIR}/candidate-manifest.json"
COPYFILE_DISABLE=1 /usr/bin/tar -czf "${STAGED_CLI_ARCHIVE}" -C "${CLI_DIR}" calrelay
COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --keepParent "${APP_BUNDLE}" "${STAGED_APP_ARCHIVE}"
if [[ "$(/usr/bin/tar -tzf "${STAGED_CLI_ARCHIVE}")" != calrelay ]]; then
    print -u2 -- "error: CLI archive must contain exactly one executable named calrelay."
    exit 1
fi
if /usr/bin/zipinfo -1 "${STAGED_APP_ARCHIVE}" | /usr/bin/grep -Ev "^CalRelay\.app(/|$)" >/dev/null; then
    print -u2 -- "error: app archive contains content outside CalRelay.app."
    exit 1
fi
CLI_SHA="$(/usr/bin/shasum -a 256 "${STAGED_CLI_ARCHIVE}" | /usr/bin/cut -d " " -f 1)"
APP_SHA="$(/usr/bin/shasum -a 256 "${STAGED_APP_ARCHIVE}" | /usr/bin/cut -d " " -f 1)"
/usr/bin/printf "{\n  \"schemaVersion\": 1,\n  \"version\": \"%s\",\n  \"architecture\": \"arm64\",\n  \"minimumMacOS\": \"26.0\",\n  \"sdk\": \"%s\",\n  \"cli\": { \"name\": \"%s\", \"sha256\": \"%s\" },\n  \"app\": { \"name\": \"%s\", \"sha256\": \"%s\" }\n}\n" "${RELEASE_VERSION}" "${SDK_VERSION}" "${CLI_ARCHIVE:t}" "${CLI_SHA}" "${APP_ARCHIVE:t}" "${APP_SHA}" > "${STAGED_MANIFEST}"
FINAL_OUTPUTS_OWNED=1
/bin/mv "${STAGED_CLI_ARCHIVE}" "${CLI_ARCHIVE}"
/bin/mv "${STAGED_APP_ARCHIVE}" "${APP_ARCHIVE}"
/bin/mv "${STAGED_MANIFEST}" "${MANIFEST}"
FINAL_OUTPUTS_COMPLETE=1
print -r -- "Built verified production artifacts for ${RELEASE_VERSION}."
