package arco

import (
	"github.com/marcbran/arcourse/cmd"
	"github.com/marcbran/jpoet/pkg/jpoet"
)

func Execute(plugins ...*jpoet.Plugin) {
	cmd.Execute(plugins)
}
