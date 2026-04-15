package arco

import (
	"github.com/marcbran/arcourse/cmd"
	"github.com/marcbran/jpoet/pkg/jpoet"
)

type Env struct {
	Cache *jpoet.Cache
}

type Init func(env Env) []*jpoet.Plugin

func Execute(init Init) {
	env := Env{Cache: jpoet.NewCache()}
	cmd.Execute(init(env))
}
