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

func (c *Client) ListAudit(ctx context.Context) ([]pkg.AuditEntry, error) {
	reqURL := c.baseURL + "/api/audit"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.client.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	if resp.StatusCode != http.StatusOK {
		var errorResp http2.ErrorResponse
		err = json.NewDecoder(resp.Body).Decode(&errorResp)
		if err != nil {
			return nil, fmt.Errorf("http %d", resp.StatusCode)
		}
		return nil, fmt.Errorf("%s", errorResp.Message)
	}
	var entries []pkg.AuditEntry
	err = json.NewDecoder(resp.Body).Decode(&entries)
	if err != nil {
		return nil, err
	}
	return entries, nil
}

func (c *Client) GetAudit(ctx context.Context, id string) (pkg.AuditEntry, error) {
	reqURL := c.baseURL + "/api/audit/" + url.PathEscape(id)
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return pkg.AuditEntry{}, err
	}
	resp, err := c.client.Do(httpReq)
	if err != nil {
		return pkg.AuditEntry{}, err
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	if resp.StatusCode != http.StatusOK {
		var errorResp http2.ErrorResponse
		err = json.NewDecoder(resp.Body).Decode(&errorResp)
		if err != nil {
			return pkg.AuditEntry{}, fmt.Errorf("http %d", resp.StatusCode)
		}
		return pkg.AuditEntry{}, fmt.Errorf("%s", errorResp.Message)
	}
	var entry pkg.AuditEntry
	err = json.NewDecoder(resp.Body).Decode(&entry)
	if err != nil {
		return pkg.AuditEntry{}, err
	}
	return entry, nil
}
