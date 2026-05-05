#!/usr/bin/env bash
set -euo pipefail

CALLER_PWD="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="${1}"
if [[ "${SPEC}" != /* ]]; then
  SPEC="${CALLER_PWD}/${SPEC}"
fi
SPEC_DIR="$(cd "$(dirname "${SPEC}")" && pwd)"
SPEC_FILE="$(basename "${SPEC}")"
SPEC_NAME="${SPEC_FILE%.*}"

"${SCRIPT_DIR}/list-detail-inference.sh" "${SPEC}"
"${SCRIPT_DIR}/list-detail-vars-inference.sh" "${SPEC}"

LIST_DETAIL_RESULTS="${SPEC_DIR}/${SPEC_NAME}/list-detail-inference/results/all.jsonnet"
VARS_RESULTS="${SPEC_DIR}/${SPEC_NAME}/list-detail-vars-inference/results/all.jsonnet"
OUTPUT="${SPEC_DIR}/${SPEC_NAME}.links.json"

cd "${SCRIPT_DIR}"
jsonnet \
  -J "${SCRIPT_DIR}" \
  -e "(import 'list-detail-links.jsonnet')(import '${SPEC}', import '${LIST_DETAIL_RESULTS}', import '${VARS_RESULTS}')" \
  > "${OUTPUT}"

echo "Wrote ${OUTPUT}"
