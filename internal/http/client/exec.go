package client

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"

	http2 "github.com/marcbran/arcourse/internal/http/server"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func (c *Client) Exec(ctx context.Context, id string) (pkg.Result, error) {
	reqURL := c.baseURL + "/api/exec/" + url.PathEscape(id)
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, reqURL, nil)
	if err != nil {
		return pkg.Result{}, err
	}
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
