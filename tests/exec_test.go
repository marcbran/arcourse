//go:build e2e

package tests

import (
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func TestExecRunsTheActionRecordedForAQuery(t *testing.T) {
	given, when, then := plugin_scenario(t)

	given.
		a_graph_root(`{
			_node: "resource",
			_action: { plugin: "test", name: "echo", data: { value: "hello" } },
		}`)

	when.
		a_path_is_queried_with_format("root", pkg.FormatJSON).and().
		the_audit_is_listed().and().
		the_audit_entry_at_index_is_fetched(0).and().
		the_action_recorded_by_the_audit_entry_is_executed()

	then.
		the_raw_output_is("echoed hello")
}

func TestExecFailsWhenTheNodeHasNoAction(t *testing.T) {
	given, when, then := plugin_scenario(t)

	given.
		a_graph_root(`{ _node: "resource", title: "hello" }`)

	when.
		a_path_is_queried_with_format("root", pkg.FormatJSON).and().
		the_audit_is_listed().and().
		the_audit_entry_at_index_is_fetched(0).and().
		the_action_recorded_by_the_audit_entry_is_executed()

	then.
		the_error_contains("node has no action")
}

func TestExecFailsWhenTheAuditEntryIsUnknown(t *testing.T) {
	given, when, then := plugin_scenario(t)

	given.
		a_graph_root(`{ _node: "resource", title: "hello" }`)

	when.
		an_unknown_action_is_executed()

	then.
		the_error_contains("audit entry not found")
}
