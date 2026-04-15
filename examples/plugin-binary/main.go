package main

import (
	"errors"

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
		})}
	})
}
