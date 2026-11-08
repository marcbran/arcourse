package main

import (
	"io/fs"
	"path/filepath"
	"strings"
	"testing"

	"github.com/marcbran/jpoet/pkg/test"
	htmlplugin "github.com/marcbran/jsonnet-plugin-html/html"
	urlplugin "github.com/marcbran/jsonnet-plugin-url/url"
)

func TestJsonnet(t *testing.T) {
	plugins := test.WithPlugins(urlplugin.Plugin(), htmlplugin.Plugin())
	mains, err := filepath.Glob("pkg/*/main.libsonnet")
	if err != nil {
		t.Fatal(err)
	}
	for _, main := range mains {
		dir := filepath.Dir(main)
		t.Run(dir, func(t *testing.T) {
			run, err := test.RunDir(dir, plugins, test.WithJPaths(filepath.Join(dir, "vendor")))
			report(t, run, err)
		})
	}
	err = filepath.WalkDir(".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() && (path == "pkg" || d.Name() == "vendor") {
			return fs.SkipDir
		}
		if d.IsDir() || !strings.HasSuffix(path, "_tests.libsonnet") {
			return nil
		}
		t.Run(path, func(t *testing.T) {
			run, err := test.RunFile(path, plugins)
			report(t, run, err)
		})
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

func report(t *testing.T, run *test.Run, err error) {
	t.Helper()
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
