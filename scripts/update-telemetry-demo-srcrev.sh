#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RECIPE="${REPO_DIR}/meta-demo/recipes-demo/telemetry-demo/telemetry-demo.bb"
REMOTE_URL="${TELEMETRY_DEMO_REMOTE:-https://github.com/SmartFlowSolution/telemetry-demo.git}"
BRANCH="${TELEMETRY_DEMO_BRANCH:-main}"

if [ ! -f "${RECIPE}" ]; then
  echo "Recipe not found: ${RECIPE}" >&2
  exit 1
fi

echo "Fetching latest telemetry-demo hash from ${REMOTE_URL} (${BRANCH})..."
LATEST_HASH="$(git ls-remote "${REMOTE_URL}" "refs/heads/${BRANCH}" | awk '{print $1}')"

if [ -z "${LATEST_HASH}" ]; then
  echo "Could not resolve latest hash for ${REMOTE_URL} branch ${BRANCH}" >&2
  exit 1
fi

CURRENT_HASH="$(sed -n 's/^SRCREV = "\(.*\)"/\1/p' "${RECIPE}")"

if [ "${CURRENT_HASH}" = "${LATEST_HASH}" ]; then
  echo "SRCREV is already up to date: ${CURRENT_HASH}"
  exit 0
fi

TMP_FILE="$(mktemp)"
sed "s/^SRCREV = \".*\"/SRCREV = \"${LATEST_HASH}\"/" "${RECIPE}" > "${TMP_FILE}"
mv "${TMP_FILE}" "${RECIPE}"

echo "Updated telemetry-demo SRCREV:"
echo "  old: ${CURRENT_HASH}"
echo "  new: ${LATEST_HASH}"
echo
echo "Review and commit the recipe change:"
echo "  git diff -- meta-demo/recipes-demo/telemetry-demo/telemetry-demo.bb"
