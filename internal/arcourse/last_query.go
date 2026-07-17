package arcourse

import (
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type LastQuery interface {
	Publish(format pkg.Format, result pkg.Result)
	Subscribe(format pkg.Format) (<-chan pkg.Result, func())
	ObservedFormats() []pkg.Format
}
