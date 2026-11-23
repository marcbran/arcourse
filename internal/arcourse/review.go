package arcourse

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/marcbran/arcourse/internal/course"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type review struct {
	course *course.Facade
}

func newReview(courseFacade *course.Facade) *review {
	return &review{course: courseFacade}
}

func (uc *review) Exec(ctx context.Context, path pkg.QueryPath, id pkg.EvaluationID, format pkg.Format) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}

	event, err := uc.course.Evaluation(ctx, course.EvaluationID(id))
	if err != nil {
		if errors.Is(err, course.ErrEvaluationNotRecorded) {
			return pkg.Result{}, fmt.Errorf("%w: %s", pkg.ErrQueryNotRecorded, id)
		}
		return pkg.Result{}, err
	}

	base, _, _ := strings.Cut(path.String(), "?")
	if pkg.NewQueryPath(base) != pkg.QueryPath(event.Address) {
		return pkg.Result{}, fmt.Errorf("%w: %s is not an evaluation of %s", pkg.ErrEvaluationMismatch, id, pkg.NewQueryPath(base))
	}

	content, err := uc.course.Content(ctx, event, course.Projection(format))
	if err != nil {
		if errors.Is(err, course.ErrContentNotRecorded) {
			return pkg.Result{}, fmt.Errorf("%w: %s has no %s content", pkg.ErrQueryNotRecorded, id, format)
		}
		return pkg.Result{}, err
	}
	if format == pkg.FormatJSON {
		content, err = withEvaluationID(content, event.EvaluationID)
		if err != nil {
			return pkg.Result{}, err
		}
	}

	return pkg.Result{Output: content, EvaluationID: id}, nil
}
