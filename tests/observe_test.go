//go:build e2e

package tests

import (
	"os"
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

// skipIfLocalCLI skips tests that require observing state published by a
// separate call: the local-cli backend spawns a fresh `arco` process per
// facade call, so there is no shared in-memory LastQuery across separate
// invocations. Observation is only meaningful within a single running
// process (e.g. a real arco serve), which is what the client backends
// (tcp-client-cli, unix-client-cli) exercise.
func skipIfLocalCLI(t *testing.T) {
	facade := os.Getenv("ARCOURSE_E2E_FACADE")
	if facade == "" || facade == "local-cli" {
		t.Skip("local-cli has no shared state across separate CLI invocations")
	}
}

func TestObserveWithoutAnyQuery(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _view:: { html: "<p>hi</p>" } }`)

	when.
		an_observer_is_subscribed(pkg.FormatJSON).and().
		no_observation_is_received()

	then.
		the_raw_output_is("")
}

func TestObserveReceivesMatchingFormatQuery(t *testing.T) {
	skipIfLocalCLI(t)
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", _view:: { html: "<p>hello</p>" } }`)

	when.
		an_observer_is_subscribed(pkg.FormatHTML).and().
		a_path_is_queried_with_format("root", pkg.FormatHTML).and().
		the_observation_is_received()

	then.
		the_raw_output_is("<p>hello</p>")
}

func TestObserveReceivesOpportunisticFormat(t *testing.T) {
	skipIfLocalCLI(t)
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", _view:: { html: "<p>hello</p>" } }`)

	when.
		an_observer_is_subscribed(pkg.FormatHTML).and().
		a_path_is_queried_with_format("root", pkg.FormatJSON).and().
		the_observation_is_received()

	then.
		the_raw_output_is("<p>hello</p>")
}

func TestObservePublishDoesNotBlockQuery(t *testing.T) {
	skipIfLocalCLI(t)
	given, when, then := scenario(t)

	given.
		a_graph_root(`{
			_node: "resource",
			child: { _node: "resource", _view:: { html: "<p>first</p>" } },
			other: { _node: "resource", _view:: { html: "<p>second</p>" } },
		}`)

	when.
		an_observer_is_subscribed(pkg.FormatHTML).and().
		a_path_is_queried_with_format("root/child", pkg.FormatHTML).and().
		a_path_is_queried_with_format_promptly("root/other", pkg.FormatHTML).and().
		the_observer_unsubscribes()

	then.
		the_raw_output_is("<p>second</p>")
}

func TestObserveUnsubscribeStopsDelivery(t *testing.T) {
	skipIfLocalCLI(t)
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", _view:: { html: "<p>hello</p>" } }`)

	when.
		an_observer_is_subscribed(pkg.FormatHTML).and().
		the_observer_unsubscribes().and().
		a_path_is_queried_with_format("root", pkg.FormatHTML).and().
		no_observation_is_received()

	then.
		the_raw_output_is("")
}
