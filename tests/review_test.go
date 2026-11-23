//go:build e2e

package tests

import (
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func TestReviewShowsTheRecordedJSONWithoutEvaluatingAgain(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", title: "hello" }`).and().
		the_path_was_queried("root")

	when.
		the_recorded_evaluation_is_reviewed_at("root", pkg.FormatJSON)

	then.
		the_output_is_the_recorded_query_output()
}

func TestReviewShowsTheRecordedHTML(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", _view:: { html: "<p>hi</p>" } }`).and().
		the_path_was_queried("root")

	when.
		the_recorded_evaluation_is_reviewed_at("root", pkg.FormatHTML)

	then.
		the_raw_output_is("<p>hi</p>")
}

func TestReviewOfAnEvaluationOfAnotherNodeIsRejected(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", child: { _node: "resource" } }`).and().
		the_path_was_queried("root")

	when.
		the_recorded_evaluation_is_reviewed_at("root/child", pkg.FormatJSON)

	then.
		the_error_contains("evaluation belongs to a different node")
}

func TestReviewOfAnEvaluationThatWasNeverRecordedIsRejected(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ _node: "resource", title: "hello" }`)

	when.
		an_evaluation_is_reviewed_at("root", "01a00000-0000-7000-8000-000000000000", pkg.FormatJSON)

	then.
		the_error_contains("query not recorded")
}
