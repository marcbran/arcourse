//go:build e2e

package tests

import (
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

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
			graph:    `{ _node: "resource", child: { _node: "resource", _queryPath:: "child", data: "big" } }`,
			path:     "root",
			expected: `{"_node":"resource","child":{"_node":"resource","_queryPath":"child"}}`,
		},
		{
			name:     "reference includes _summary when present",
			graph:    `{ _node: "resource", child: { _node: "resource", _queryPath:: "c", _summary: "A child", data: 42 } }`,
			path:     "root",
			expected: `{"_node":"resource","child":{"_node":"resource","_queryPath":"c","_summary":"A child"}}`,
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

func TestQueryNodeWithParams(t *testing.T) {
	cases := []struct {
		name     string
		graph    string
		path     string
		params   map[string]any
		expected string
	}{
		{
			name: "params resolved into visible _params object",
			graph: `{
				child: {
					_node: true,
					_paramSpecs: [
						{ name: 'page', type: 'number', default: 1 },
						{ name: 'pageSize', type: 'number' },
					],
					value: 42,
				},
			}`,
			path:     "root/child",
			params:   map[string]any{"pageSize": "100"},
			expected: `{"_node":true,"_paramSpecs":[{"name":"page","type":"number","default":1},{"name":"pageSize","type":"number"}],"_params":{"pageSize":100,"page":1},"value":42}`,
		},
		{
			name: "optional param falls back to default",
			graph: `{
				child: {
					_node: true,
					_paramSpecs: [{ name: 'page', type: 'number', default: 1 }],
					value: 42,
				},
			}`,
			path:     "root/child",
			params:   nil,
			expected: `{"_node":true,"_paramSpecs":[{"name":"page","type":"number","default":1}],"_params":{"page":1},"value":42}`,
		},
		{
			name: "array params applied from repeated values",
			graph: `{
				child: {
					_node: true,
					_paramSpecs: [{ name: 'tags', type: 'array', items: 'string' }],
				},
			}`,
			path:     "root/child",
			params:   map[string]any{"tags": []any{"a", "b"}},
			expected: `{"_node":true,"_paramSpecs":[{"name":"tags","type":"array","items":"string"}],"_params":{"tags":["a","b"]}}`,
		},
		{
			name: "number array params applied from repeated values",
			graph: `{
				child: {
					_node: true,
					_paramSpecs: [{ name: 'ids', type: 'array', items: 'number' }],
				},
			}`,
			path:     "root/child",
			params:   map[string]any{"ids": []any{1, 2}},
			expected: `{"_node":true,"_paramSpecs":[{"name":"ids","type":"array","items":"number"}],"_params":{"ids":[1,2]}}`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph_root(tc.graph)

			when.
				a_path_is_queried_with_params(tc.path, tc.params)

			then.
				the_output_is(tc.expected)
		})
	}
}

func TestQueryPathWithEmbeddedQueryString(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{
			child: {
				_node: true,
				_paramSpecs: [
					{ name: 'page', type: 'number', default: 1 },
					{ name: 'pageSize', type: 'number', default: 25 },
				],
				value: 42,
			},
		}`)

	when.
		a_path_is_queried("root/child?page=3&pageSize=50")

	then.
		the_output_is(`{"_node":true,"_paramSpecs":[{"name":"page","type":"number","default":1},{"name":"pageSize","type":"number","default":25}],"_params":{"page":3,"pageSize":50},"value":42}`)
}

func TestQueryPathWithEmbeddedQueryStringOverriddenByExplicitParams(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{
			child: {
				_node: true,
				_paramSpecs: [{ name: 'page', type: 'number', default: 1 }],
				value: 42,
			},
		}`)

	when.
		a_path_is_queried_with_params("root/child?page=3", map[string]any{"page": "9"})

	then.
		the_output_is(`{"_node":true,"_paramSpecs":[{"name":"page","type":"number","default":1}],"_params":{"page":9},"value":42}`)
}

func TestQueryInvalidParams(t *testing.T) {
	cases := []struct {
		name   string
		graph  string
		path   string
		params map[string]any
		err    string
	}{
		{
			name: "undeclared parameter",
			graph: `{
				child: {
					_node: true,
					_paramSpecs: [{ name: 'page', type: 'number', default: 1 }],
				},
			}`,
			path:   "root/child",
			params: map[string]any{"unknown": "1"},
			err:    "undeclared parameter",
		},
		{
			name: "required parameter missing",
			graph: `{
				child: {
					_node: true,
					_paramSpecs: [{ name: 'pageSize', type: 'number' }],
				},
			}`,
			path:   "root/child",
			params: nil,
			err:    "required parameter",
		},
		{
			name: "value cannot be coerced",
			graph: `{
				child: {
					_node: true,
					_paramSpecs: [{ name: 'page', type: 'number' }],
				},
			}`,
			path:   "root/child",
			params: map[string]any{"page": "true"},
			err:    "cannot be coerced to number",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph_root(tc.graph)

			when.
				a_path_is_queried_with_params(tc.path, tc.params)

			then.
				the_error_contains(tc.err)
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

func TestQueryPrimaryFormatNotAvailableOnNode(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _view:: { html: "<p>hi</p>" } }`)

	when.
		a_path_is_queried_with_format("root", pkg.FormatJsonnet)

	then.
		the_error_contains("no jsonnet view")
}

func TestQueryPathAsHTML(t *testing.T) {
	cases := []struct {
		name     string
		graph    string
		path     string
		expected string
	}{
		{
			name:     "root node",
			graph:    `{ _view:: { html: "<p>hi</p>" } }`,
			path:     "root",
			expected: `<p>hi</p>`,
		},
		{
			name:     "nested child",
			graph:    `{ child: { _view:: { html: "<span>child</span>" } } }`,
			path:     "root/child",
			expected: `<span>child</span>`,
		},
		{
			name:     "deeply nested path",
			graph:    `{ a: { b: { _view:: { html: "<div>deep</div>" } } } }`,
			path:     "root/a/b",
			expected: `<div>deep</div>`,
		},
		{
			name:     "path segment with hyphen",
			graph:    `{ "my-node": { _view:: { html: "<p>hyphen</p>" } } }`,
			path:     "root/my-node",
			expected: `<p>hyphen</p>`,
		},
		{
			name:     "function field applied to next segment",
			graph:    `{ get: function(name) { _view:: { html: "<p>" + name + "</p>" } } }`,
			path:     "root/get/alice",
			expected: `<p>alice</p>`,
		},
		{
			name:     "chained function fields",
			graph:    `{ owner: function(o) { repo: function(r) { _view:: { html: "<p>" + o + "/" + r + "</p>" } } } }`,
			path:     "root/owner/marcbran/repo/arcourse",
			expected: `<p>marcbran/arcourse</p>`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph_root(tc.graph)

			when.
				a_path_is_queried_with_format(tc.path, pkg.FormatHTML)

			then.
				the_raw_output_is(tc.expected)
		})
	}
}

func TestQueryPathAsJsonnet(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ child: { _view:: { jsonnet: "local x = 1;\nx" } } }`)

	when.
		a_path_is_queried_with_format("root/child", pkg.FormatJsonnet)

	then.
		the_raw_output_is("local x = 1;\nx")
}

func TestQueryNodeWithParamsAsHTML(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{
			child: {
				local node = self,
				_paramSpecs: [{ name: 'name', type: 'string' }],
				_view:: { html: '<p>' + node._params.name + '</p>' },
			},
		}`)

	when.
		a_path_is_queried_with_params_and_format("root/child", map[string]any{"name": "alice"}, pkg.FormatHTML)

	then.
		the_raw_output_is("<p>alice</p>")
}

func TestQueryInvalidParamsAsHTML(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{
			child: {
				_paramSpecs: [{ name: 'page', type: 'number' }],
				_view:: { html: '<p>ok</p>' },
			},
		}`)

	when.
		a_path_is_queried_with_params_and_format("root/child", map[string]any{"unknown": "1"}, pkg.FormatHTML)

	then.
		the_error_contains("undeclared parameter")
}

func TestQueryPathNotFoundAsHTML(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ child: { _view:: { html: "<p>hi</p>" } } }`)

	when.
		a_path_is_queried_with_format("root/nonexistent", pkg.FormatHTML)

	then.
		the_error_contains("nonexistent")
}

func TestQuerySpecializedNode(t *testing.T) {
	graph := `
local root = import 'root';
[[
  [['users', 'me'], {
    local n = self,
    _paramSpecs: [{ name: 'include', type: 'string', default: null }],
    data: { id: 'U1', include: std.get(n._params, 'include', null) },
  }],
  [['incidents'], {
    local n = self,
    _paramSpecs: [
      { name: 'status', type: 'string', default: null },
      { name: 'user', type: 'string', default: null },
    ],
    data: { status: std.get(n._params, 'status', null), user: std.get(n._params, 'user', null) },
  }],
  [['incidents', 'triggered'], root.incidents {
    _params+: { status: 'triggered', user: root.users.me.data.id },
  }],
]]
`
	tcs := []struct {
		name     string
		path     string
		expected string
	}{
		{
			name:     "node-level params apply without request params",
			path:     "root/incidents/triggered",
			expected: `{"status":"triggered","user":"U1"}`,
		},
		{
			name:     "request params override node-level params",
			path:     "root/incidents/triggered?status=acknowledged",
			expected: `{"status":"acknowledged","user":"U1"}`,
		},
		{
			name:     "base node keeps its own defaults",
			path:     "root/incidents",
			expected: `{"status":null,"user":null}`,
		},
	}
	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_node_graph(graph)

			when.
				a_path_is_queried(tc.path)

			then.
				the_output_field_is("data", tc.expected)
		})
	}
}
