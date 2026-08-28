package arcourse

import (
	"context"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type observe struct {
	lastQuery LastQuery
}

func newObserve(lastQuery LastQuery) *observe {
	return &observe{lastQuery: lastQuery}
}

func (uc *observe) Exec(ctx context.Context, format pkg.Format) (<-chan pkg.Result, func()) {
	return uc.lastQuery.Subscribe(format)
}
