package client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	http2 "github.com/marcbran/arcourse/internal/arcourse/http/server"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type queryRequest struct {
	Path     string         `json:"path"`
	Params   map[string]any `json:"params"`
	Format   string         `json:"format"`
	Session  string         `json:"session"`
	From     string         `json:"from"`
	FromPath string         `json:"fromPath"`
}

func (c *Client) Query(ctx context.Context, path pkg.QueryPath, params map[string]any, format pkg.Format, origin pkg.Origin) (pkg.Result, error) {
	body, err := json.Marshal(queryRequest{Path: path.String(), Params: params, Format: string(format), Session: string(origin.Session), From: string(origin.From), FromPath: origin.FromPath.String()})
	if err != nil {
		return pkg.Result{}, err
	}
	url := c.baseURL + "/api/query"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return pkg.Result{}, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	resp, err := c.client.Do(httpReq)
	if err != nil {
		return pkg.Result{}, err
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	if resp.StatusCode != http.StatusOK {
		var errorResp http2.ErrorResponse
		err = json.NewDecoder(resp.Body).Decode(&errorResp)
		if err != nil {
			return pkg.Result{}, fmt.Errorf("http %d", resp.StatusCode)
		}
		return pkg.Result{}, fmt.Errorf("%s", errorResp.Message)
	}
	var out outputResponse
	err = json.NewDecoder(resp.Body).Decode(&out)
	if err != nil {
		return pkg.Result{}, err
	}
	return pkg.Result{Output: out.Output}, nil
}
