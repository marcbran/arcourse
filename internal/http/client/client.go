package client

import (
	"context"
	"fmt"
	"net"
	"net/http"

	archttp "github.com/marcbran/arcourse/internal/http"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Client struct {
	baseURL string
	client  *http.Client
}

func New(cfg archttp.Config) pkg.Facade {
	if cfg.UnixSocket != "" {
		return &Client{
			baseURL: "http://unix",
			client: &http.Client{
				Transport: &http.Transport{
					DialContext: func(ctx context.Context, network string, addr string) (net.Conn, error) {
						var d net.Dialer
						return d.DialContext(ctx, "unix", cfg.UnixSocket)
					},
				},
			},
		}
	}

	host := cfg.Hostname
	if host == "" {
		host = "localhost"
	}
	port := cfg.Port
	if port == "" {
		port = "8080"
	}
	baseURL := fmt.Sprintf("http://%s:%s", host, port)
	return &Client{
		baseURL: baseURL,
		client:  &http.Client{},
	}
}
