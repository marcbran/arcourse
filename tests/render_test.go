//go:build e2e

package tests

import (
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func TestRenderPathAsHTML(t *testing.T) {
	cases := []struct {
		name      string
		rootGraph string
		nodeGraph string
		path      []string
		expected  string
	}{
		{
			name:      "root node",
			rootGraph: `{ _view:: { html: "<p>hi</p>" } }`,
			path:      []string{"root"},
			expected:  `<p>hi</p>`,
		},
		{
			name:      "nested child",
			rootGraph: `{ child: { _view:: { html: "<span>child</span>" } } }`,
			path:      []string{"root", "child"},
			expected:  `<span>child</span>`,
		},
		{
			name:      "deeply nested path",
			rootGraph: `{ a: { b: { _view:: { html: "<div>deep</div>" } } } }`,
			path:      []string{"root", "a", "b"},
			expected:  `<div>deep</div>`,
		},
		{
			name:      "path segment with hyphen",
			rootGraph: `{ "my-node": { _view:: { html: "<p>hyphen</p>" } } }`,
			path:      []string{"root", "my-node"},
			expected:  `<p>hyphen</p>`,
		},
		{
			name:      "function field applied to next segment",
			rootGraph: `{ get: function(name) { _view:: { html: "<p>" + name + "</p>" } } }`,
			path:      []string{"root", "get", "alice"},
			expected:  `<p>alice</p>`,
		},
		{
			name:      "chained function fields",
			rootGraph: `{ owner: function(o) { repo: function(r) { _view:: { html: "<p>" + o + "/" + r + "</p>" } } } }`,
			path:      []string{"root", "owner", "marcbran", "repo", "arcourse"},
			expected:  `<p>marcbran/arcourse</p>`,
		},
		{
			name: "render prefix node body when deeper static node also exists",
			nodeGraph: `[
  [
    [['a'], { _view:: { html: "<p>prefix</p>" } }, []],
    [['a', 'b'], { _view:: { html: "<p>deep</p>" } }, []]
  ]
]`,
			path:     []string{"root", "a"},
			expected: `<p>prefix</p>`,
		},
		{
			name: "render deeper static node past prefix node",
			nodeGraph: `[
  [
    [['a'], { _view:: { html: "<p>prefix</p>" } }, []],
    [['a', 'b'], { _view:: { html: "<p>deep</p>" } }, []]
  ]
]`,
			path:     []string{"root", "a", "b"},
			expected: `<p>deep</p>`,
		},
		{
			name: "render deeper variable node past prefix variable node",
			nodeGraph: `[
  [
    [['courses', '$course'], { _view:: { html: "<p>course</p>" } }, []],
    [['courses', '$course', 'lessons', '$lesson'], { _view:: { html: "<p>lesson</p>" } }, []]
  ]
]`,
			path:     []string{"root", "courses", "course", "math", "lessons", "lesson", "intro"},
			expected: `<p>lesson</p>`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			if tc.nodeGraph != "" {
				given.a_node_graph(tc.nodeGraph)
			} else {
				given.a_graph_root(tc.rootGraph)
			}

			when.
				a_path_is_rendered(tc.path, pkg.FormatHTML)

			then.
				the_raw_output_is(tc.expected)
		})
	}
}

func TestRenderPathNotFound(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ child: { _view:: { html: "<p>hi</p>" } } }`)

	when.
		a_path_is_rendered([]string{"root", "nonexistent"}, pkg.FormatHTML)

	then.
		the_error_contains("nonexistent")
}
