package arcourse

import (
	"context"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Observe struct {
	lastQuery LastQuery
}

func NewObserve(lastQuery LastQuery) *Observe {
	return &Observe{lastQuery: lastQuery}
}

func (uc *Observe) Exec(ctx context.Context, format pkg.Format) (<-chan pkg.Result, func()) {
	return uc.lastQuery.Subscribe(format)
}
