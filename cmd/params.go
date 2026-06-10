package cmd

import (
	"fmt"
	"strings"
)

func parseParams(flags []string) (map[string]any, error) {
	params := map[string]any{}
	for _, flag := range flags {
		key, value, ok := strings.Cut(flag, "=")
		if !ok || key == "" {
			return nil, fmt.Errorf("invalid param %q: expected key=value", flag)
		}
		if existing, ok := params[key]; ok {
			switch existing := existing.(type) {
			case []string:
				params[key] = append(existing, value)
			case string:
				params[key] = []string{existing, value}
			default:
				return nil, fmt.Errorf("invalid repeated param %q", key)
			}
		} else {
			params[key] = value
		}
	}
	return params, nil
}
