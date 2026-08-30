package arcourse

import "context"

type warm struct {
	environment *environment
}

func newWarm(environment *environment) *warm {
	return &warm{environment: environment}
}

func (uc *warm) Exec(ctx context.Context) error {
	return uc.environment.Warm(ctx)
}
