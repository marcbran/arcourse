//go:build e2e

package tests

import "testing"

func TestEvaluateSimpleExpression(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root("42")

	when.
		an_expression_is_evaluated("root")

	then.
		the_output_is("42")
}

func TestEvaluateGraphJsonnetOnly(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_node_graph(`[[[['seg'], { n: 99 }]]]`)

	when.
		an_expression_is_evaluated("root.seg.n")

	then.
		the_output_is("99")
}

func TestEvaluateGraphAndExpressionCombinations(t *testing.T) {
	cases := []struct {
		name       string
		graph      string
		expression string
		expected   string
	}{
		{
			name:       "number root",
			graph:      "42",
			expression: "root",
			expected:   "42",
		},
		{
			name:       "object root",
			graph:      "{ message: 'hello' }",
			expression: "root",
			expected:   `{"message":"hello"}`,
		},
		{
			name:       "derived object from root",
			graph:      "{ value: 2 }",
			expression: "{ doubled: root.value * 2 }",
			expected:   `{"doubled":4}`,
		},
		{
			name:       "array from root field",
			graph:      "{ items: [1, 2, 3] }",
			expression: "root.items",
			expected:   "[1, 2, 3]",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph_root(tc.graph)

			when.
				an_expression_is_evaluated(tc.expression)

			then.
				the_output_is(tc.expected)
		})
	}
}

func TestImportRoot(t *testing.T) {
	cases := []struct {
		name       string
		setup      func(*Stage) *Stage
		expression string
		expected   string
	}{
		{
			name: "import root in expression resolves to assembled graph (export format)",
			setup: func(s *Stage) *Stage {
				return s.a_graph_root(`{ value: 42 }`)
			},
			expression: `(import 'root').value`,
			expected:   `42`,
		},
		{
			name: "import root in expression resolves to assembled graph (easy format)",
			setup: func(s *Stage) *Stage {
				return s.a_node_graph(`[[[['seg'], { n: 7 }]]]`)
			},
			expression: `(import 'root').seg.n`,
			expected:   `7`,
		},
		{
			name: "import root and root variable are the same graph",
			setup: func(s *Stage) *Stage {
				return s.a_graph_root(`{ value: 42 }`)
			},
			expression: `{ via_root: root.value, via_import: (import 'root').value }`,
			expected:   `{"via_root":42,"via_import":42}`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			tc.setup(given)

			when.
				an_expression_is_evaluated(tc.expression)

			then.
				the_output_is(tc.expected)
		})
	}
}

func TestTruncateDescendantNodesToReferences(t *testing.T) {
	cases := []struct {
		name       string
		graph      string
		expression string
		expected   string
	}{
		{
			name:       "own fields and plain objects included fully",
			graph:      `{ _node: "resource", title: "hello", meta: { x: 1 } }`,
			expression: `root`,
			expected:   `{"_node":"resource","title":"hello","meta":{"x":1}}`,
		},
		{
			name:       "descendant node replaced with reference",
			graph:      `{ _node: "resource", child: { _node: "resource", _evalPath:: "child", data: "big" } }`,
			expression: `root`,
			expected:   `{"_node":"resource","child":{"_node":"resource","_evalPath":"child"}}`,
		},
		{
			name:       "reference includes _summary when present",
			graph:      `{ _node: "resource", child: { _node: "resource", _evalPath:: "c", _summary: "A child", data: 42 } }`,
			expression: `root`,
			expected:   `{"_node":"resource","child":{"_node":"resource","_evalPath":"c","_summary":"A child"}}`,
		},
		{
			name:       "no _node markers produces unmodified output",
			graph:      `{ title: "plain", nested: { x: 1 } }`,
			expression: `root`,
			expected:   `{"title":"plain","nested":{"x":1}}`,
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph_root(tc.graph)

			when.
				an_expression_is_evaluated(tc.expression)

			then.
				the_output_is(tc.expected)
		})
	}
}
