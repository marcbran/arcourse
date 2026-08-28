package arcourse

import "context"

type warm struct {
	root *root
}

func newWarm(root *root) *warm {
	return &warm{root: root}
}

func (uc *warm) Exec(ctx context.Context) error {
	_, err := uc.root.Snippet(ctx)
	return err
}
