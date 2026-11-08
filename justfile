tool := "go tool -modfile=tools/go.mod"

bench:
    go test -tags e2e -bench=. -benchmem -run=^$ ./tests/...

build-go:
    go build -o arco .

build-jsonnet: vendor-jsonnet
    for dir in pkg/*/; do \
        [ -f "$dir/main.libsonnet" ] || continue; \
        rm -rf "$dir/build" && {{tool}} jpoet pkg build -J "${dir}vendor" "$dir" || exit 1; \
    done

build: build-go build-jsonnet

check-lib-sync:
    for f in internal/arcourse/lib/arcourse-graph/*.libsonnet; do \
        diff -q "$f" "pkg/arcourse-graph/$(basename "$f")" || exit 1; \
    done
    for f in internal/arcourse/lib/arcourse-ui/*; do \
        diff -q "$f" "pkg/arcourse-ui/components/$(basename "$f")" || exit 1; \
    done

check: check-lib-sync

ci: lint vuln test test-race check build test-e2e

install:
    dest=$(go env GOBIN); [ -n "$dest" ] || dest=$(go env GOPATH)/bin; go build -o "$dest/arco" .

lint:
    {{tool}} golangci-lint run ./...

push-jsonnet: build-jsonnet
    for dir in pkg/*/; do \
        [ -f "$dir/main.libsonnet" ] || continue; \
        {{tool}} jpoet pkg push "$dir" || exit 1; \
    done

push: push-jsonnet

test-e2e:
    status=0; \
    just test-e2e-facade local-cli || status=1; \
    just test-e2e-facade tcp-client-cli || status=1; \
    just test-e2e-facade unix-client-cli || status=1; \
    exit $status

test-e2e-facade facade:
    ARCO_BINARY="$(pwd)/arco" ARCOURSE_E2E_FACADE="{{facade}}" go test -v -tags e2e ./tests/...

test-go: vendor-jsonnet
    go test -v -cover -timeout=120s -parallel=10 ./...

test-jsonnet: vendor-jsonnet
    go test -count=1 -run TestJsonnet .

test-race:
    go test -v -race -timeout=120s ./...

test: test-go test-jsonnet

vendor-jsonnet:
    for dir in pkg/*/; do \
        [ -f "$dir/jsonnetfile.json" ] || continue; \
        (cd "$dir" && go tool -modfile=../../tools/go.mod jb install) || exit 1; \
    done

vuln:
    {{tool}} govulncheck ./...
