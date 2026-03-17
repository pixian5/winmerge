#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
DIST_DIR="${SCRIPT_DIR}/dist"
VERSION_FILE="${SCRIPT_DIR}/VERSION"

usage() {
  cat <<'EOF'
Usage: mac/build-mac.sh [--release] [--version <version>]

Builds the macOS WinMerge app bundle (Release configuration), then packages it
as a zip ready to upload to GitHub Releases.

Options:
  --release         Build and package, then bump VERSION by 0.0.1 for the next release.
  --version <v>     Override the version string for this build (default reads mac/VERSION).
                    Supports semantic versions (x.y.z) or timestamp format (YYMMDDHHMI).
  -h, --help        Show this help.

Notes:
- Must be run on macOS with Xcode command line tools installed.
- Output: mac/dist/WinMerge-macOS-<version>.zip
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must run on macOS (detected $(uname -s))." >&2
  exit 1
fi

RELEASE_MODE=0
OVERRIDE_VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      RELEASE_MODE=1
      shift
      ;;
    --version)
      OVERRIDE_VERSION="${2:-}"
      if [[ -z "${OVERRIDE_VERSION}" ]]; then
        echo "Missing value for --version" >&2
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "0.0.1" > "${VERSION_FILE}"
fi

VERSION_TO_BUILD="${OVERRIDE_VERSION:-$(tr -d '[:space:]' < "${VERSION_FILE}")}"
if [[ -z "${VERSION_TO_BUILD}" ]]; then
  echo "Version string cannot be empty." >&2
  exit 1
fi

echo "==> Building WinMerge macOS ${VERSION_TO_BUILD}"
rm -rf "${BUILD_DIR}"
# Release configuration for both single-config (CMAKE_BUILD_TYPE) and Xcode multi-config generators.
cmake -S "${SCRIPT_DIR}" -B "${BUILD_DIR}" -DWM_VERSION="${VERSION_TO_BUILD}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${BUILD_DIR}" --config Release

APP_PATH="${BUILD_DIR}/WinMerge.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Expected bundle not found: ${APP_PATH}" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
ARCHIVE_PATH="${DIST_DIR}/WinMerge-macOS-${VERSION_TO_BUILD}.zip"
rm -f "${ARCHIVE_PATH}"
echo "==> Packaging ${APP_PATH} -> ${ARCHIVE_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ARCHIVE_PATH}"

if [[ ${RELEASE_MODE} -eq 1 ]]; then
  # Check if version is semantic (x.y.z) or timestamp (YYMMDDHHMI)
  if [[ "${VERSION_TO_BUILD}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    # Semantic version format
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"

    # Use base-10 prefix so numeric components are always treated as decimal (even if a component has leading zeros).
    major_num=$((10#${major}))
    minor_num=$((10#${minor}))
    patch_num=$((10#${patch}))
    next_patch=$((patch_num + 1))
    NEXT_VERSION="${major_num}.${minor_num}.${next_patch}"
  elif [[ "${VERSION_TO_BUILD}" =~ ^[0-9]{10}$ ]]; then
    # Timestamp format (YYMMDDHHMI) - generate new timestamp
    NEXT_VERSION="$(date -u '+%y%m%d%H%M')"
  else
    echo "Version must match <major>.<minor>.<patch> or YYMMDDHHMI format, got '${VERSION_TO_BUILD}'" >&2
    exit 1
  fi
  echo "${NEXT_VERSION}" > "${VERSION_FILE}"
  echo "==> Release artifact ready: ${ARCHIVE_PATH}"
  echo "    Upload to GitHub Releases using tag \"v${VERSION_TO_BUILD}\" (per mac/README.md), then next version set to ${NEXT_VERSION}"
else
  echo "==> Build artifact ready: ${ARCHIVE_PATH}"
  echo "    (Use --release to bump mac/VERSION for the next publish)"
fi
