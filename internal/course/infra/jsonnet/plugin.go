package jsonnet

import (
	"github.com/google/go-jsonnet"
	"github.com/marcbran/jpoet/pkg/jpoet"

	"github.com/marcbran/arcourse/internal/course"
)

func Plugin(repo Repo) (*jpoet.Plugin, *Watch) {
	natives := newNatives(repo)
	watch := newWatch()
	functions := []jsonnet.NativeFunction{
		{
			Name: "sessions",
			Func: func(args []any) (any, error) {
				return natives.sessions()
			},
		},
		{
			Name: "session",
			Func: func(args []any) (any, error) {
				return natives.session(course.SessionID(stringArg(args, 0)))
			},
		},
		{
			Name: "visit",
			Func: func(args []any) (any, error) {
				return natives.visit(course.VisitID(stringArg(args, 0)))
			},
		},
		{
			Name: "evaluation",
			Func: func(args []any) (any, error) {
				return natives.evaluation(course.EvaluationID(stringArg(args, 0)))
			},
		},
	}
	return jpoet.NewPlugin("course", functions, jpoet.WithWatchSource(watch)), watch
}

func stringArg(args []any, index int) string {
	if len(args) <= index {
		return ""
	}
	value, _ := args[index].(string)
	return value
}
