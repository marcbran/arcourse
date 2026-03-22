build:
    go build -o arco .

install:
    dest=$(go env GOBIN); [ -n "$dest" ] || dest=$(go env GOPATH)/bin; go build -o "$dest/arco" .

test:
    go test ./...

lint:
    go vet ./...
