package client

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"

	http2 "github.com/marcbran/arcourse/internal/http/server"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func (c *Client) Watch(ctx context.Context, path string, params map[string]any, format pkg.Format) (<-chan pkg.Result, func(), error) {
	values := url.Values{}
	values.Set("path", path)
	values.Set("format", string(format))
	if len(params) > 0 {
		paramsJSON, err := json.Marshal(params)
		if err != nil {
			return nil, nil, err
		}
		values.Set("params", string(paramsJSON))
	}

	streamCtx, cancel := context.WithCancel(ctx)

	streamURL := c.baseURL + "/api/watch?" + values.Encode()
	httpReq, err := http.NewRequestWithContext(streamCtx, http.MethodGet, streamURL, nil)
	if err != nil {
		cancel()
		return nil, nil, err
	}
	resp, err := c.client.Do(httpReq)
	if err != nil {
		cancel()
		return nil, nil, err
	}
	if resp.StatusCode != http.StatusOK {
		defer func() {
			_ = resp.Body.Close()
		}()
		cancel()
		var errorResp http2.ErrorResponse
		err = json.NewDecoder(resp.Body).Decode(&errorResp)
		if err != nil {
			return nil, nil, fmt.Errorf("http %d", resp.StatusCode)
		}
		return nil, nil, fmt.Errorf("%s", errorResp.Message)
	}

	ch := make(chan pkg.Result)
	go func() {
		defer close(ch)
		defer func() {
			_ = resp.Body.Close()
		}()

		scanner := bufio.NewScanner(resp.Body)
		scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
		for scanner.Scan() {
			line := scanner.Text()
			data, ok := strings.CutPrefix(line, "data: ")
			if !ok {
				continue
			}
			var out outputResponse
			err = json.Unmarshal([]byte(data), &out)
			if err != nil {
				continue
			}
			select {
			case ch <- pkg.Result{Output: out.Output}:
			case <-streamCtx.Done():
				return
			}
		}
	}()

	return ch, cancel, nil
}
