//go:build e2e

package tests

import "testing"

func TestEvaluateSimpleExpression(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph("42")

	when.
		an_expression_is_evaluated("root")

	then.
		the_output_is("42")
}
