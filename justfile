
test-go:
    go test -v -cover -timeout=120s -parallel=10 ./...

test-jsonnet:
    jpoet test .

test: test-go test-jsonnet

lint:
    golangci-lint run ./...

build:
    go build -o arco .

install:
    dest=$(go env GOBIN); [ -n "$dest" ] || dest=$(go env GOPATH)/bin; go build -o "$dest/arco" .

test-e2e:
    status=0; \
    just test-e2e-facade local-cli || status=1; \
    just test-e2e-facade tcp-client-cli || status=1; \
    just test-e2e-facade unix-client-cli || status=1; \
    exit $status

test-e2e-facade facade:
    ARCO_BINARY="$(pwd)/arco" ARCOURSE_E2E_FACADE="{{facade}}" go test -v -tags e2e ./tests/...

ci: lint test build test-e2e
