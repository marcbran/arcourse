package client

import (
	"context"
	"errors"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func (c *Client) Compile(ctx context.Context) (pkg.Result, error) {
	return pkg.Result{}, errors.New("compile is not supported in client mode: run it against a local evaluate directory")
}

func (c *Client) Warm(ctx context.Context) error {
	return errors.New("warm is not supported in client mode: it runs automatically when the server starts")
}
