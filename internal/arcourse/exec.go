package arcourse

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/marcbran/arcourse/internal/arcourse/course"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

const actionField = "_action"

type Command struct {
	Plugin   string         `json:"plugin"`
	Name     string         `json:"name"`
	Data     map[string]any `json:"data"`
	Redirect *nodeRef       `json:"redirect"`
}

type nodeRef struct {
	QueryPath string `json:"_queryPath"`
}

type Executor interface {
	Exec(ctx context.Context, plugin string, action string, data map[string]any) (string, error)
}

type exec struct {
	course      *course.Facade
	environment *environment
}

func newExec(courseFacade *course.Facade, environment *environment) *exec {
	return &exec{course: courseFacade, environment: environment}
}

func (uc *exec) Exec(ctx context.Context, id pkg.EvaluationID) (pkg.ExecResult, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.ExecResult{}, err
	}

	event, err := uc.course.Evaluation(ctx, course.EvaluationID(id))
	if err != nil {
		if errors.Is(err, course.ErrEvaluationNotRecorded) {
			return pkg.ExecResult{}, fmt.Errorf("%w: %s", pkg.ErrQueryNotRecorded, id)
		}
		return pkg.ExecResult{}, err
	}

	stored, err := uc.course.Content(ctx, event, course.Projection(pkg.FormatJSON))
	if err != nil {
		if errors.Is(err, course.ErrContentNotRecorded) {
			return pkg.ExecResult{}, fmt.Errorf("%w: %s", pkg.ErrContentNotRecorded, event.Address)
		}
		return pkg.ExecResult{}, err
	}

	body, err := withEvaluationID(stored, event.EvaluationID)
	if err != nil {
		return pkg.ExecResult{}, err
	}

	command, err := decodeCommand(body, pkg.QueryPath(event.Address))
	if err != nil {
		return pkg.ExecResult{}, err
	}

	output, err := uc.environment.Exec(ctx, command.Plugin, command.Name, command.Data)
	if err != nil {
		return pkg.ExecResult{}, err
	}

	redirect := pkg.QueryPath(event.Address)
	if command.Redirect != nil && command.Redirect.QueryPath != "" {
		redirect = pkg.NewQueryPath(command.Redirect.QueryPath)
	}
	return pkg.ExecResult{Output: output, Redirect: redirect}, nil
}

func decodeCommand(body string, path pkg.QueryPath) (Command, error) {
	var node map[string]json.RawMessage
	err := json.Unmarshal([]byte(body), &node)
	if err != nil {
		return Command{}, err
	}
	raw, ok := node[actionField]
	if !ok {
		return Command{}, fmt.Errorf("%w: %s", pkg.ErrActionNotFound, path)
	}
	var command Command
	err = json.Unmarshal(raw, &command)
	if err != nil {
		return Command{}, err
	}
	if command.Plugin == "" || command.Name == "" {
		return Command{}, fmt.Errorf("%w: %s: plugin and name are required", pkg.ErrActionNotFound, path)
	}
	return command, nil
}
