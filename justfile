
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
    ARCO_BINARY="$(pwd)/arco" go test -v -tags e2e ./tests/...

ci: lint test build test-e2e
