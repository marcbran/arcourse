//go:build e2e

package tests

import (
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func TestAuditPersistsSuccessfulQuery(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", title: "hello", _view:: { html: "<p>hello</p>" } }`)

	when.
		a_path_is_queried_with_format("root", pkg.FormatHTML).and().
		the_audit_is_listed().and().
		the_audit_entry_at_index_is_fetched(0)

	then.
		the_audit_has_entry_count(1).and().
		audit_entry_at_index_has_path(0, "root").and().
		the_fetched_audit_entry_path_is("root").and().
		the_fetched_audit_entry_html_is("<p>hello</p>").and().
		the_fetched_audit_entry_json_is(`{"_node":"resource","title":"hello"}`)
}

func TestAuditListsQueriesChronologically(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{
			_node: "resource",
			first: { _node: "resource", _view:: { html: "<p>first</p>" } },
			second: { _node: "resource", _view:: { html: "<p>second</p>" } },
		}`)

	when.
		a_path_is_queried_with_format("root/first", pkg.FormatHTML).and().
		a_path_is_queried_with_format("root/second", pkg.FormatHTML).and().
		the_audit_is_listed()

	then.
		the_audit_has_entry_count(2).and().
		audit_entry_at_index_has_path(0, "root/first").and().
		audit_entry_at_index_has_path(1, "root/second").and().
		the_audit_entries_are_in_chronological_order()
}

func TestReplayShowsCapturedDataNotFreshRecomputation(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", _view:: { html: "<p>original</p>" } }`)

	when.
		a_path_is_queried_with_format("root", pkg.FormatHTML).and().
		the_audit_is_listed().and().
		a_graph_root(`{ _node: "resource", _view:: { html: "<p>changed</p>" } }`).and().
		the_audit_entry_at_index_is_fetched(0)

	then.
		the_fetched_audit_entry_html_is("<p>original</p>")
}
