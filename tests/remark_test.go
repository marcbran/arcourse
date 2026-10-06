//go:build e2e

package tests

import (
	"testing"
)

func TestRemarkIsAttachedToTheQueriedVisit(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", title: "hello" }`)

	when.
		a_path_is_queried("root").and().
		a_remark_is_made_on_the_query("looks healthy")

	then.
		the_remarks_recorded_for_the_query_are("looks healthy")
}

func TestRemarkFailsWithEmptyText(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", title: "hello" }`)

	when.
		a_path_is_queried("root").and().
		a_remark_is_made_on_the_query("   ")

	then.
		the_error_contains("remark text is empty").and().
		the_remarks_recorded_for_the_query_are()
}

func TestRemarkFailsWhenTheQueryIsUnknown(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", title: "hello" }`)

	when.
		a_remark_is_made_on_an_unknown_query("looks healthy")

	then.
		the_error_contains("query not recorded")
}

func TestRemarkFailsWhenTheNodeIsNotRecorded(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", _record: false, title: "hello" }`)

	when.
		a_path_is_queried("root").and().
		a_remark_is_made_on_the_query("looks healthy")

	then.
		the_error_contains("query not recorded")
}
