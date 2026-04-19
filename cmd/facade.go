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
	jsonnetinfra "github.com/marcbran/arcourse/internal/infra/jsonnet"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"sigs.k8s.io/yaml"
)

type Config struct {
	arcourse.Config
	HTTP archttp.Config `json:"http"`
}

func buildFacade(cfg Config, plugins []*jpoet.Plugin) pkg.Facade {
	jpaths := []string{filepath.Join(cfg.Evaluate.Dir, "vendor")}
	evaluator := jsonnetinfra.NewEvaluator(arcourse.Lib, jpaths, plugins)
	return arcourse.NewFacade(cfg.Config, evaluator)
}

func loadConfig() (Config, error) {
	home, err := findHome()
	if err != nil {
		return Config{}, err
	}
	cfgPath, err := findConfigFile(home)
	if err != nil {
		return Config{}, err
	}
	data, err := os.ReadFile(cfgPath)
	if err != nil {
		return Config{}, err
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
		return Config{}, err
	}
	workspace := strings.TrimSpace(cfg.Evaluate.Dir)
	if workspace == "" {
		workspace = home
	}
	if !filepath.IsAbs(workspace) {
		workspace = filepath.Join(home, workspace)
	}
	workspace, err = filepath.Abs(filepath.Clean(workspace))
	if err != nil {
		return Config{}, err
	}
	entry := filepath.Join(workspace, "root.jsonnet")
	fi, err := os.Stat(entry)
	if err != nil {
		if os.IsNotExist(err) {
			return Config{}, fmt.Errorf("%w: %s", pkg.ErrRootJsonnetNotFound, entry)
		}
		return Config{}, err
	}
	if !fi.Mode().IsRegular() {
		return Config{}, fmt.Errorf("%w: %s", pkg.ErrRootJsonnetNotFound, entry)
	}
	cfg.Evaluate.Dir = workspace
	return cfg, nil
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
	return "", fmt.Errorf("no config.yaml, config.yml, or config.json in %s", home)
}
