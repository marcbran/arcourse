package jsonnet

import (
	"time"

	"github.com/google/go-jsonnet"
	"github.com/google/uuid"
	"github.com/marcbran/jpoet/pkg/jpoet"
)

func newPlugin() *jpoet.Plugin {
	return jpoet.NewPlugin("arcourse", []jsonnet.NativeFunction{
		{
			Name: "uuid",
			Func: func(args []any) (any, error) {
				return uuid.Must(uuid.NewV7()).String(), nil
			},
		},
		{
			Name: "now",
			Func: func(args []any) (any, error) {
				return time.Now().Format(time.RFC3339), nil
			},
		},
	})
}
