package cmd

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/marcbran/arcourse/internal/arcourse"
	jsonnetinfra "github.com/marcbran/arcourse/internal/infra/jsonnet"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"sigs.k8s.io/yaml"
)

func NewFacade(plugins []*jpoet.Plugin) (pkg.Facade, error) {
	cfg, err := loadConfig()
	if err != nil {
		return nil, err
	}
	evaluator := jsonnetinfra.NewEvaluator(arcourse.Lib, plugins)
	return arcourse.NewFacade(cfg, evaluator), nil
}

func loadConfig() (arcourse.Config, error) {
	home, err := findHome()
	if err != nil {
		return arcourse.Config{}, err
	}
	cfgPath, err := findConfigFile(home)
	if err != nil {
		return arcourse.Config{}, err
	}
	data, err := os.ReadFile(cfgPath)
	if err != nil {
		return arcourse.Config{}, err
	}
	var cfg arcourse.Config
	ext := strings.ToLower(filepath.Ext(cfgPath))
	switch ext {
	case ".json":
		err = json.Unmarshal(data, &cfg)
	default:
		err = yaml.Unmarshal(data, &cfg)
	}
	if err != nil {
		return arcourse.Config{}, err
	}
	if cfg.Evaluate.Root == "" {
		return arcourse.Config{}, pkg.ErrRootConfigNotConfigured
	}
	root := cfg.Evaluate.Root
	if !filepath.IsAbs(root) {
		root = filepath.Join(home, root)
	}
	root, err = filepath.Abs(root)
	if err != nil {
		return arcourse.Config{}, err
	}
	cfg.Evaluate.Root = root
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
