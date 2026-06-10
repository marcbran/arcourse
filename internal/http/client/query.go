package client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	http2 "github.com/marcbran/arcourse/internal/http/server"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type queryRequest struct {
	Path   string         `json:"path"`
	Params map[string]any `json:"params"`
}

func (c *Client) Query(ctx context.Context, path string, params map[string]any) (pkg.Result, error) {
	body, err := json.Marshal(queryRequest{Path: path, Params: params})
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
