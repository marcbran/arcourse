package arcourse

import (
	"context"
	"encoding/json"
	"fmt"

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
	auditRepo   AuditRepo
	environment *environment
}

func newExec(auditRepo AuditRepo, environment *environment) *exec {
	return &exec{auditRepo: auditRepo, environment: environment}
}

func (uc *exec) Exec(ctx context.Context, id string) (pkg.ExecResult, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.ExecResult{}, err
	}

	entry, err := uc.auditRepo.Get(ctx, id)
	if err != nil {
		return pkg.ExecResult{}, err
	}

	command, err := decodeCommand(entry)
	if err != nil {
		return pkg.ExecResult{}, err
	}

	output, err := uc.environment.Exec(ctx, command.Plugin, command.Name, command.Data)
	if err != nil {
		return pkg.ExecResult{}, err
	}

	redirect := entry.Path
	if command.Redirect != nil && command.Redirect.QueryPath != "" {
		redirect = command.Redirect.QueryPath
	}
	return pkg.ExecResult{Output: output, Redirect: redirect}, nil
}

func decodeCommand(entry pkg.AuditEntry) (Command, error) {
	result, ok := entry.Results[pkg.FormatJSON]
	if !ok {
		return Command{}, fmt.Errorf("%w: %s", pkg.ErrAuditJSONNotRecorded, entry.ID)
	}
	var node map[string]json.RawMessage
	err := json.Unmarshal([]byte(result.Output), &node)
	if err != nil {
		return Command{}, err
	}
	raw, ok := node[actionField]
	if !ok {
		return Command{}, fmt.Errorf("%w: %s", pkg.ErrActionNotFound, entry.Path)
	}
	var command Command
	err = json.Unmarshal(raw, &command)
	if err != nil {
		return Command{}, err
	}
	if command.Plugin == "" || command.Name == "" {
		return Command{}, fmt.Errorf("%w: %s: plugin and name are required", pkg.ErrActionNotFound, entry.Path)
	}
	return command, nil
}
