package main

import (
	"testing"

	"github.com/marcbran/jpoet/pkg/test"
	htmlplugin "github.com/marcbran/jsonnet-plugin-html/html"
	urlplugin "github.com/marcbran/jsonnet-plugin-url/url"
)

func TestJsonnet(t *testing.T) {
	run, err := test.RunDir(".", test.WithPlugins(urlplugin.Plugin(), htmlplugin.Plugin()))
	if err != nil {
		t.Fatal(err)
	}
	for _, result := range run.Results {
		if !result.Equal {
			t.Errorf("%s\n  actual:   %v\n  expected: %v", result.Name, result.Actual, result.Expected)
		}
	}
	t.Logf("passed %d/%d", run.PassedCount, run.TotalCount)
}
