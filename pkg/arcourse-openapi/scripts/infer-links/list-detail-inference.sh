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
WORKDIR="${2:-"${SPEC_DIR}/${SPEC_NAME}/list-detail-inference"}"
if [[ "${WORKDIR}" != /* ]]; then
  WORKDIR="${CALLER_PWD}/${WORKDIR}"
fi
BUNDLES_DIR="${WORKDIR}/bundles"
RESULTS_DIR="${WORKDIR}/results"
SCHEMA="${SCRIPT_DIR}/list-detail-inference-output.schema.json"
MODEL="${CODEX_MODEL:-gpt-5.5}"
LIMIT="${LIMIT:-}"

mkdir -p "${WORKDIR}" "${RESULTS_DIR}"

rm -rf "${BUNDLES_DIR}"
cd "${SCRIPT_DIR}"
jpoet eval \
  -d "${SCRIPT_DIR}" \
  -s \
  -c "(import 'list-detail-inference-bundles.jsonnet')(import '${SPEC}')" \
  -o "${BUNDLES_DIR}"

cat > "${WORKDIR}/prompt.md" <<'PROMPT'
Read input.json.

Infer whether the OpenAPI list response at sourcePath has a canonical GET detail path among detailPaths.

Return only JSON matching the provided schema.

Rules:
- Choose "detail_elsewhere" only when there is a clear canonical detail GET endpoint for the list item type.
- Choose "no_detail_get" when the list item is an event, stats/summary object, search result, relationship record, activity feed item, or otherwise has no canonical detail GET path in detailPaths.
- Choose "uncertain" when there is not enough evidence.
- For "detail_elsewhere", targetPath must be one path from detailPaths and array must be the array path from input.json.
- For "no_detail_get" or "uncertain", targetPath must be null.
- Do not invent paths.
- Do not infer variable mappings.
PROMPT

count=0
for input in "${BUNDLES_DIR}"/*/input.json; do
  bundle="$(basename "$(dirname "${input}")")"
  bundle_dir="$(dirname "${input}")"
  output="${RESULTS_DIR}/${bundle}.json"

  if [[ -f "${output}" && "${FORCE:-}" != "1" ]]; then
    continue
  fi

  cp "${WORKDIR}/prompt.md" "${bundle_dir}/prompt.md"

  codex exec \
    --cd "${bundle_dir}" \
    --skip-git-repo-check \
    --ephemeral \
    --sandbox read-only \
    --model "${MODEL}" \
    --output-schema "${SCHEMA}" \
    --output-last-message "${output}" \
    "Read prompt.md and input.json. Return only JSON." \
    </dev/null

  count=$((count + 1))
  if [[ -n "${LIMIT}" && "${count}" -ge "${LIMIT}" ]]; then
    break
  fi
done

echo "Wrote results to ${RESULTS_DIR}"

IMPORTS_FILE="${RESULTS_DIR}/all.jsonnet"
{
  echo '['
  find "${RESULTS_DIR}" -maxdepth 1 -type f -name '*.json' \
    | sort \
    | while IFS= read -r file; do
        basename="$(basename "${file}")"
        echo "  import '${basename}',"
      done
  echo ']'
} > "${IMPORTS_FILE}"

echo "Wrote ${IMPORTS_FILE}"
