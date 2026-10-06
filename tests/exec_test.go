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
		the_action_recorded_for_the_query_is_executed()

	then.
		the_raw_output_is("echoed hello").and().
		an_execution_is_recorded_for_the_query("succeeded").and().
		the_recorded_execution_output_is("echoed hello")
}

func TestExecFailsWhenTheActionFails(t *testing.T) {
	given, when, then := plugin_scenario(t)

	given.
		a_graph_root(`{
			_node: "resource",
			_action: { plugin: "test", name: "echo", data: {} },
		}`)

	when.
		a_path_is_queried_with_format("root", pkg.FormatJSON).and().
		the_action_recorded_for_the_query_is_executed()

	then.
		the_error_contains("value must be provided").and().
		an_execution_is_recorded_for_the_query("failed").and().
		the_recorded_execution_error_contains("value must be provided")
}

func TestExecRefusesToRunTheSameQueryTwice(t *testing.T) {
	given, when, then := plugin_scenario(t)

	given.
		a_graph_root(`{
			_node: "resource",
			_action: { plugin: "test", name: "echo", data: { value: "hello" } },
		}`)

	when.
		a_path_is_queried_with_format("root", pkg.FormatJSON).and().
		the_action_recorded_for_the_query_is_executed().and().
		the_action_recorded_for_the_query_is_executed_again()

	then.
		the_error_contains("query already executed").and().
		an_execution_is_recorded_for_the_query("succeeded")
}

func TestExecFailsWhenTheNodeHasNoAction(t *testing.T) {
	given, when, then := plugin_scenario(t)

	given.
		a_graph_root(`{ _node: "resource", title: "hello" }`)

	when.
		a_path_is_queried_with_format("root", pkg.FormatJSON).and().
		the_action_recorded_for_the_query_is_executed()

	then.
		the_error_contains("node has no action").and().
		no_execution_is_recorded_for_the_query()
}

func TestExecFailsWhenTheQueryIsUnknown(t *testing.T) {
	given, when, then := plugin_scenario(t)

	given.
		a_graph_root(`{ _node: "resource", title: "hello" }`)

	when.
		an_unknown_action_is_executed()

	then.
		the_error_contains("query not recorded")
}
