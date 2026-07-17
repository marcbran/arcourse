package cmd

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/marcbran/arcourse/internal/arcourse"
	archttp "github.com/marcbran/arcourse/internal/http"
	"github.com/marcbran/arcourse/internal/http/client"
	"github.com/marcbran/arcourse/internal/infra/broadcast"
	jsonnetinfra "github.com/marcbran/arcourse/internal/infra/jsonnet"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"sigs.k8s.io/yaml"
)

var errNoConfigFile = errors.New("no config file")

func buildFacade(cfg Config, plugins []*jpoet.Plugin) pkg.Facade {
	if cfg.Mode == ModeClient {
		return client.New(cfg.HTTP)
	}
	return buildLocalFacade(cfg, plugins)
}

func buildLocalFacade(cfg Config, plugins []*jpoet.Plugin) pkg.Facade {
	jpaths := []string{filepath.Join(cfg.Evaluate.Dir, "vendor")}
	evaluator := jsonnetinfra.NewEvaluator(arcourse.Lib, jpaths, plugins)
	lastQuery := broadcast.NewLastQuery()
	return arcourse.NewFacade(cfg.Config, evaluator, lastQuery)
}

type Config struct {
	arcourse.Config
	Mode Mode           `json:"mode"`
	HTTP archttp.Config `json:"http"`
}

type Mode string

const (
	ModeLocal  Mode = "local"
	ModeClient Mode = "client"
)

func (m *Mode) UnmarshalJSON(data []byte) error {
	var s string
	err := json.Unmarshal(data, &s)
	if err != nil {
		return err
	}
	switch {
	case s == "":
		*m = ModeLocal
	case Mode(s) == ModeLocal || Mode(s) == ModeClient:
		*m = Mode(s)
	default:
		return fmt.Errorf("invalid mode %q", s)
	}
	return nil
}

func (m Mode) MarshalJSON() ([]byte, error) {
	return json.Marshal(string(m))
}

func loadConfig() (Config, error) {
	cfg, home, err := readConfig()
	if err != nil {
		return Config{}, err
	}
	return resolveConfigValues(cfg, home)
}

func readConfig() (Config, string, error) {
	home, err := findHome()
	if err != nil {
		return Config{}, "", err
	}
	cfgPath, err := findConfigFile(home)
	if err != nil {
		if errors.Is(err, errNoConfigFile) {
			return defaultConfig(), home, nil
		}
		return Config{}, "", err
	}
	data, err := os.ReadFile(cfgPath)
	if err != nil {
		return Config{}, "", err
	}
	var cfg Config
	ext := strings.ToLower(filepath.Ext(cfgPath))
	switch ext {
	case ".json":
		err = json.Unmarshal(data, &cfg)
	default:
		err = yaml.Unmarshal(data, &cfg)
	}
	if err != nil {
		return Config{}, "", err
	}
	return cfg, home, nil
}

func findHome() (string, error) {
	v := os.Getenv("ARCOURSE_HOME")
	if v != "" {
		return filepath.Clean(v), nil
	}
	v = os.Getenv("XDG_CONFIG_HOME")
	if v != "" {
		return filepath.Join(v, "arcourse"), nil
	}
	home := os.Getenv("HOME")
	if home == "" {
		return "", errors.New("HOME is not set and ARCOURSE_HOME and XDG_CONFIG_HOME are not set")
	}
	return filepath.Join(home, ".config", "arcourse"), nil
}

func findConfigFile(home string) (string, error) {
	names := []string{"config.yaml", "config.yml", "config.json"}
	for _, name := range names {
		p := filepath.Join(home, name)
		_, err := os.Stat(p)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return "", err
		}
		return p, nil
	}
	return "", fmt.Errorf("%w: no config.yaml, config.yml, or config.json in %s", errNoConfigFile, home)
}

func defaultConfig() Config {
	return Config{
		Mode: ModeClient,
		HTTP: archttp.Config{
			Hostname: "localhost",
			Port:     "1183",
		},
		Config: arcourse.Config{
			Evaluate: arcourse.EvaluateConfig{},
		},
	}
}

func resolveConfigValues(cfg Config, home string) (Config, error) {
	cfg = mergeConfigDefaults(cfg)
	evaluateDir, err := resolveRelativeDir(home, cfg.Evaluate.Dir)
	if err != nil {
		return Config{}, err
	}
	cfg.Evaluate.Dir = evaluateDir
	return cfg, nil
}

func resolveRelativeDir(parent string, d string) (string, error) {
	dir := strings.TrimSpace(d)
	if dir == "" {
		dir = parent
	}
	if !filepath.IsAbs(dir) {
		dir = filepath.Join(parent, dir)
	}
	return filepath.Abs(filepath.Clean(dir))
}

func mergeConfigDefaults(cfg Config) Config {
	def := defaultConfig()
	if cfg.Mode == "" {
		cfg.Mode = def.Mode
	}
	if strings.TrimSpace(cfg.HTTP.Hostname) == "" {
		cfg.HTTP.Hostname = def.HTTP.Hostname
	}
	if strings.TrimSpace(cfg.HTTP.Port) == "" {
		cfg.HTTP.Port = def.HTTP.Port
	}
	if strings.TrimSpace(cfg.Evaluate.Dir) == "" {
		cfg.Evaluate.Dir = def.Evaluate.Dir
	}
	return cfg
}
