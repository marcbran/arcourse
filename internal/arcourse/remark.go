package arcourse

import (
	"context"
	"errors"
	"fmt"

	"github.com/marcbran/arcourse/internal/course"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type remark struct {
	course *course.Facade
}

func newRemark(courseFacade *course.Facade) *remark {
	return &remark{course: courseFacade}
}

func (uc *remark) Exec(ctx context.Context, id pkg.EvaluationID, text string) (pkg.RemarkID, error) {
	remarkID, err := uc.course.Remark(ctx, course.EvaluationID(id), text)
	if err != nil {
		if errors.Is(err, course.ErrEvaluationNotRecorded) {
			return "", fmt.Errorf("%w: %s", pkg.ErrQueryNotRecorded, id)
		}
		if errors.Is(err, course.ErrEmptyRemark) {
			return "", pkg.ErrEmptyRemark
		}
		return "", err
	}
	return pkg.RemarkID(remarkID), nil
}
