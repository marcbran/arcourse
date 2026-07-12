//go:build e2e

package tests

import "testing"

func TestEvaluateFacetNodeWithPlugin(t *testing.T) {
	given, when, then := plugin_scenario(t)

	given.
		a_graph_root(`{ _node: "facet", value: std.native('invoke:test')('echo', ["hello"]) }`)

	when.
		an_expression_is_evaluated("root")

	then.
		the_output_is(`{"_node":"facet","value":"hello"}`)
}

func TestTruncateFacetDescendantWithoutInvokingPlugin(t *testing.T) {
	given, when, then := plugin_scenario(t)

	given.
		a_graph_root(`{ _node: "resource", facet: { _node: "facet", _evalPath:: "facet", value: std.native('invoke:test')('missing', ["hello"]) } }`)

	when.
		an_expression_is_evaluated("root")

	then.
		the_output_is(`{"_node":"resource","facet":{"_node":"facet","_evalPath":"facet"}}`)
}
