package client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"

	http2 "github.com/marcbran/arcourse/internal/arcourse/http/server"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type remarkRequest struct {
	Text string `json:"text"`
}

type remarkResponse struct {
	RemarkID string `json:"remarkId"`
}

func (c *Client) Remark(ctx context.Context, id pkg.EvaluationID, text string) (pkg.RemarkID, error) {
	body, err := json.Marshal(remarkRequest{Text: text})
	if err != nil {
		return "", err
	}
	reqURL := c.baseURL + "/api/remark/" + url.PathEscape(string(id))
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, reqURL, bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	resp, err := c.client.Do(httpReq)
	if err != nil {
		return "", err
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	if resp.StatusCode != http.StatusOK {
		var errorResp http2.ErrorResponse
		err = json.NewDecoder(resp.Body).Decode(&errorResp)
		if err != nil {
			return "", fmt.Errorf("http %d", resp.StatusCode)
		}
		return "", fmt.Errorf("%s", errorResp.Message)
	}
	var out remarkResponse
	err = json.NewDecoder(resp.Body).Decode(&out)
	if err != nil {
		return "", err
	}
	return pkg.RemarkID(out.RemarkID), nil
}
