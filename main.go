package main

import (
	"github.com/marcbran/arcourse/pkg/arco"
	"github.com/marcbran/jpoet/pkg/jpoet"
)

func main() {
	arco.Execute(func(env arco.Env) []*jpoet.Plugin {
		return nil
	})
}
