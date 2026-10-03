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

type execResponse struct {
	Output   string `json:"output"`
	Redirect string `json:"redirect"`
}

func (c *Client) Exec(ctx context.Context, id pkg.EvaluationID) (pkg.ExecResult, error) {
	reqURL := c.baseURL + "/api/exec/" + url.PathEscape(string(id))
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, reqURL, nil)
	if err != nil {
		return pkg.ExecResult{}, err
	}
	resp, err := c.client.Do(httpReq)
	if err != nil {
		return pkg.ExecResult{}, err
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	if resp.StatusCode != http.StatusOK {
		var errorResp http2.ErrorResponse
		err = json.NewDecoder(resp.Body).Decode(&errorResp)
		if err != nil {
			return pkg.ExecResult{}, fmt.Errorf("http %d", resp.StatusCode)
		}
		return pkg.ExecResult{}, fmt.Errorf("%s", errorResp.Message)
	}
	var out execResponse
	err = json.NewDecoder(resp.Body).Decode(&out)
	if err != nil {
		return pkg.ExecResult{}, err
	}
	return pkg.ExecResult{Output: out.Output, Redirect: pkg.NewQueryPath(out.Redirect)}, nil
}
