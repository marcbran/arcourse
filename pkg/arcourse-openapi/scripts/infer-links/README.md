# OpenAPI Link Inference

These scripts infer list-to-detail links for an OpenAPI spec and write a
`<spec-name>.links.json` file next to the spec.

## Requirements

- `jsonnet`
- `jpoet`
- `codex` CLI
- an OpenAPI spec JSON file

## Usage

Run the combined script with the spec path:

```sh
pkg/arcourse-openapi/scripts/infer-links/infer-links.sh path/to/github.json
```

For a spec named `github.json`, this creates:

```text
path/to/github/list-detail-inference/
path/to/github/list-detail-vars-inference/
path/to/github.links.json
```

The final `github.links.json` contains link objects with:

```json
{
  "sourcePath": "/user/repos",
  "targetPath": "/repos/{owner}/{repo}",
  "array": [],
  "vars": {
    "owner": ["owner", "login"],
    "repo": ["name"]
  }
}
```

## Workflow

`infer-links.sh` runs two inference steps:

1. `list-detail-inference.sh`
   Infers whether each list endpoint maps to a canonical detail endpoint.

2. `list-detail-vars-inference.sh`
   Infers which array-item properties supply missing target path params.

Then it combines the results with `list-detail-links.jsonnet`.

## Useful Options

Limit new Codex calls while testing:

```sh
LIMIT=1 pkg/arcourse-openapi/scripts/infer-links/infer-links.sh path/to/github.json
```

Use a different model:

```sh
CODEX_MODEL=gpt-5.5 pkg/arcourse-openapi/scripts/infer-links/infer-links.sh path/to/github.json
```

Re-run jobs even when result files already exist:

```sh
FORCE=1 pkg/arcourse-openapi/scripts/infer-links/infer-links.sh path/to/github.json
```

Skipped existing result files do not count toward `LIMIT`.

## Running Steps Manually

```sh
pkg/arcourse-openapi/scripts/infer-links/list-detail-inference.sh path/to/github.json
pkg/arcourse-openapi/scripts/infer-links/list-detail-vars-inference.sh path/to/github.json
```

Both scripts also accept an optional second argument for a custom workdir.
