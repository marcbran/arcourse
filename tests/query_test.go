//go:build e2e

package tests

import "testing"

func TestQueryNodeByPath(t *testing.T) {
	cases := []struct {
		name     string
		graph    string
		path     string
		expected string
	}{
		{
			name:     "root node",
			graph:    `{ _node: "resource", title: "hello" }`,
			path:     "root",
			expected: `{"_node":"resource","title":"hello"}`,
		},
		{
			name:     "nested child",
			graph:    `{ child: { _node: "resource", value: 42 } }`,
			path:     "root/child",
			expected: `{"_node":"resource","value":42}`,
		},
		{
			name:     "descendant nodes truncated to references",
			graph:    `{ _node: "resource", child: { _node: "resource", _path: "child", data: "big" } }`,
			path:     "root",
			expected: `{"_node":"resource","child":{"_node":"resource","_path":"child"}}`,
		},
		{
			name:     "reference includes _summary when present",
			graph:    `{ _node: "resource", child: { _node: "resource", _path: "c", _summary: "A child", data: 42 } }`,
			path:     "root",
			expected: `{"_node":"resource","child":{"_node":"resource","_path":"c","_summary":"A child"}}`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph_root(tc.graph)

			when.
				a_path_is_queried(tc.path)

			then.
				the_output_is(tc.expected)
		})
	}
}

func TestQueryPathNotFound(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ child: { _node: "resource" } }`)

	when.
		a_path_is_queried("root/nonexistent")

	then.
		the_error_contains("nonexistent")
}
