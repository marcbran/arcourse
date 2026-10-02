package main

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/go-jsonnet"
	"github.com/google/go-jsonnet/ast"
	"github.com/marcbran/arcourse/pkg/arco"
	"github.com/marcbran/jpoet/pkg/jpoet"
)

func main() {
	arco.Execute(func(_ arco.Env) []*jpoet.Plugin {
		return []*jpoet.Plugin{jpoet.NewPlugin("test", []jsonnet.NativeFunction{
			{
				Name:   "echo",
				Params: ast.Identifiers{"value"},
				Func: func(args []any) (any, error) {
					if len(args) != 1 {
						return nil, errors.New("value must be provided")
					}
					return args[0], nil
				},
			},
		}, jpoet.WithAction("echo", func(_ context.Context, data map[string]any) (string, error) {
			value, ok := data["value"]
			if !ok {
				return "", errors.New("value must be provided")
			}
			return fmt.Sprintf("echoed %v", value), nil
		}))}
	})
}
