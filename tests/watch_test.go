//go:build e2e

package tests

import (
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func TestWatchEvaluatesImmediatelyWithoutAPriorQuery(t *testing.T) {
	skipIfLocalCLI(t)
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", _view:: { html: "<p>hi</p>" } }`)

	when.
		a_watcher_subscribes_to("root", pkg.FormatHTML).and().
		the_watch_event_is_received()

	then.
		the_raw_output_is("<p>hi</p>")
}

func TestWatchReceivesTheQueryThatEstablishedIt(t *testing.T) {
	skipIfLocalCLI(t)
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", _view:: { html: "<p>hello</p>" } }`)

	when.
		a_path_is_queried_with_format("root", pkg.FormatHTML).and().
		a_watcher_subscribes_to("root", pkg.FormatHTML).and().
		the_watch_event_is_received()

	then.
		the_raw_output_is("<p>hello</p>")
}

func TestWatchReceivesLaterQueryOfSamePath(t *testing.T) {
	skipIfLocalCLI(t)
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", _view:: { html: "<p>first</p>" } }`)

	when.
		a_watcher_subscribes_to("root", pkg.FormatHTML).and().
		a_path_is_queried_with_format_promptly("root", pkg.FormatHTML).and().
		the_watch_event_is_received()

	then.
		the_raw_output_is("<p>first</p>")
}

func TestWatchUnsubscribeStopsDelivery(t *testing.T) {
	skipIfLocalCLI(t)
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", _view:: { html: "<p>hello</p>" } }`)

	when.
		a_watcher_subscribes_to("root", pkg.FormatHTML).and().
		the_watcher_unsubscribes().and().
		a_path_is_queried_with_format("root", pkg.FormatHTML).and().
		no_watch_event_is_received()

	then.
		the_raw_output_is("")
}

func TestWatchOnlyDeliversToMatchingPath(t *testing.T) {
	skipIfLocalCLI(t)
	given, when, then := scenario(t)

	given.
		a_graph_root(`{
			_node: "resource",
			child: { _node: "resource", _view:: { html: "<p>first</p>" } },
			other: { _node: "resource", _view:: { html: "<p>second</p>" } },
		}`)

	when.
		a_watcher_subscribes_to("root/child", pkg.FormatHTML).and().
		the_watch_event_is_received_and_watcher_stays_subscribed().and().
		a_path_is_queried_with_format_promptly("root/other", pkg.FormatHTML).and().
		no_watch_event_is_received()

	then.
		the_raw_output_is("")
}
