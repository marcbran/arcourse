package client

import (
	"fmt"
	"net/http"

	archttp "github.com/marcbran/arcourse/internal/http"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Client struct {
	baseURL string
	client  *http.Client
}

func New(cfg archttp.Config) pkg.Facade {
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
