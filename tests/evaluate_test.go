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
		a_node_graph(`[[['seg'], { n: 99 }, []]]`)

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
			graph:      `{ _node: "resource", child: { _node: "resource", _path: "child", data: "big" } }`,
			expression: `root`,
			expected:   `{"_node":"resource","child":{"_node":"resource","_path":"child"}}`,
		},
		{
			name:       "reference includes _summary when present",
			graph:      `{ _node: "resource", child: { _node: "resource", _path: "c", _summary: "A child", data: 42 } }`,
			expression: `root`,
			expected:   `{"_node":"resource","child":{"_node":"resource","_path":"c","_summary":"A child"}}`,
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
