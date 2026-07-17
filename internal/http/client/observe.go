package client

import (
	"bufio"
	"context"
	"encoding/json"
	"net/http"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func (c *Client) Observe(ctx context.Context, format pkg.Format) (<-chan pkg.Result, func()) {
	ch := make(chan pkg.Result)
	streamCtx, cancel := context.WithCancel(ctx)

	go func() {
		defer close(ch)

		url := c.baseURL + "/observe/stream?format=" + string(format)
		httpReq, err := http.NewRequestWithContext(streamCtx, http.MethodGet, url, nil)
		if err != nil {
			return
		}
		resp, err := c.client.Do(httpReq)
		if err != nil {
			return
		}
		defer func() {
			_ = resp.Body.Close()
		}()
		if resp.StatusCode != http.StatusOK {
			return
		}

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

	return ch, cancel
}
