build:
    go build -o arco .

install:
    dest=$(go env GOBIN); [ -n "$dest" ] || dest=$(go env GOPATH)/bin; go build -o "$dest/arco" .

test:
    go test ./...

test-e2e:
    ARCO_BINARY="$(pwd)/arco" go test -v -tags e2e ./tests/...

lint:
    go vet ./...
