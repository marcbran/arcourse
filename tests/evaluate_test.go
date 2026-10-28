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

func TestEvaluateCompiledGraph(t *testing.T) {
	cases := []struct {
		name       string
		graph      string
		expression string
		expected   string
	}{
		{
			name:       "static descendant nodes",
			graph:      `[[[['x'], { u: 1 }], [['x', 'y'], { v: 2 }]]]`,
			expression: `[root.x.u, root.x.y.v]`,
			expected:   `[1, 2]`,
		},
		{
			name:       "variable descendant node knows its paths",
			graph:      `[[[['namespaces'], { title: 'Namespaces' }], [['namespaces', '$name', 'pods'], { kind: 'PodList' }]]]`,
			expression: `local pods = root.namespaces.name('default').pods; { name: pods.name, kind: pods.kind, evalPath: pods._evalPath, queryPath: pods._queryPath }`,
			expected:   `{"name": "default", "kind": "PodList", "evalPath": "root.namespaces.name(\"default\").pods", "queryPath": "/root/namespaces/name/default/pods"}`,
		},
		{
			name:       "layers of one spec merge in source order",
			graph:      `[[[['demo'], { value: 'base' }, { value: 'final', extra: true }]]]`,
			expression: `[root.demo.value, root.demo.extra]`,
			expected:   `["final", true]`,
		},
		{
			name:       "specs at the same path merge in source order",
			graph:      `[[[['demo'], { n: 1, label: 'first' }], [['demo'], { label: 'second' }]]]`,
			expression: `[root.demo.n, root.demo.label]`,
			expected:   `[1, "second"]`,
		},
		{
			name:       "default view applies to nodes and intermediate levels",
			graph:      `[[[['a', 'b'], { n: 1 }]], { _view:: 'default' }]`,
			expression: `[root.a._view, root.a.b._view]`,
			expected:   `["default", "default"]`,
		},
		{
			name:       "view from a later spec suppresses the default view",
			graph:      `[[[['demo'], { n: 1 }], [['demo'], { _view:: 'custom' }]], { _view:: 'default' }]`,
			expression: `root.demo._view`,
			expected:   `"custom"`,
		},
		{
			name:       "sibling variables stay separate",
			graph:      `[[[['parents', '$a'], { from: 'a' }], [['parents', '$b'], { from: 'b' }]]]`,
			expression: `[root.parents.a('x').from, root.parents.a('x').a, root.parents.b('y').from, root.parents.b('y').b]`,
			expected:   `["a", "x", "b", "y"]`,
		},
		{
			name:       "functions in node bodies stay callable",
			graph:      `[[[['demo'], { render(x):: x + 1 }]]]`,
			expression: `root.demo.render(41)`,
			expected:   `42`,
		},
		{
			name:       "segments that are not identifiers",
			graph:      `[[[['my-app', '$the-var', 'a"b'], { n: 1 }]]]`,
			expression: `root['my-app']['the-var']('v')['a"b'].n`,
			expected:   `1`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_node_graph(tc.graph)

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
