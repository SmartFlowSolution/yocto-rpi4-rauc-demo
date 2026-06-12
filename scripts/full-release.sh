#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/build-image.sh"
"${SCRIPT_DIR}/build-rauc.sh"
"${SCRIPT_DIR}/build-sdk.sh"
"${SCRIPT_DIR}/release.sh" "${VERSION}"
