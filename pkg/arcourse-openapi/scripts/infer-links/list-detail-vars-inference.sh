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
WORKDIR="${2:-"${SPEC_DIR}/${SPEC_NAME}/list-detail-vars-inference"}"
if [[ "${WORKDIR}" != /* ]]; then
  WORKDIR="${CALLER_PWD}/${WORKDIR}"
fi
BUNDLES_DIR="${WORKDIR}/bundles"
RESULTS_DIR="${WORKDIR}/results"
LIST_DETAIL_RESULTS="${SPEC_DIR}/${SPEC_NAME}/list-detail-inference/results/all.jsonnet"
SCHEMA="${SCRIPT_DIR}/list-detail-vars-inference-output.schema.json"
MODEL="${CODEX_MODEL:-gpt-5.5}"
LIMIT="${LIMIT:-}"

mkdir -p "${WORKDIR}" "${RESULTS_DIR}"

rm -rf "${BUNDLES_DIR}"
cd "${SCRIPT_DIR}"
jpoet eval \
  -d "${SCRIPT_DIR}" \
  -s \
  -c "(import 'list-detail-vars-inference-bundles.jsonnet')(import '${SPEC}', import '${LIST_DETAIL_RESULTS}')" \
  -o "${BUNDLES_DIR}"

cat > "${WORKDIR}/prompt.md" <<'PROMPT'
Read input.json.

Infer JSON property paths on the array item that provide values for the target path params listed in missingParams.

Return only JSON matching the provided schema.

Rules:
- Only infer vars for params in missingParams.
- Each vars value must be a property path relative to the array item, for example ["account", "id"] or ["name"].
- Do not include params that are already present in inheritedParams.
- Do not invent properties that are not supported by itemSchema.
- Match the meaning of each target path param, not just its name.
- Prefer stable canonical identifiers over display names.
- Prefer exact or clearly equivalent property names when available, for example an "id" param from an "id" property, or a "name" param from a "name" property.
- For params ending in "_id" or named "id", prefer stable id-like fields over names, slugs, titles, or URLs.
- For params ending in "_name" or named "name", prefer stable name-like fields over display titles or descriptions.
- For slug/key/code params, prefer slug/key/code fields over human-readable labels.
- Avoid URLs, descriptions, titles, summaries, display names, timestamps, booleans, counts, and status fields unless the target param clearly asks for that value.
- Return vars as an array of objects with param and path fields.
- If a missing param cannot be resolved from itemSchema, omit it from vars and explain that in reason.
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
