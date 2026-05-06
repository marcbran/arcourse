package http

type Config struct {
	Hostname   string `json:"hostname"`
	Port       string `json:"port"`
	UnixSocket string `json:"unixSocket"`
}
