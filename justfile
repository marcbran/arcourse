build:
    go build -o arco .

install:
    dest=$(go env GOBIN); [ -n "$dest" ] || dest=$(go env GOPATH)/bin; go build -o "$dest/arco" .

test-go:
    go test ./...

test-jsonnet:
    jpoet test .

test:
    just test-go
    just test-jsonnet

test-go-e2e:
    ARCO_BINARY="$(pwd)/arco" go test -v -tags e2e ./tests/...

test-e2e:
    just test-go-e2e

lint:
    go vet ./...
