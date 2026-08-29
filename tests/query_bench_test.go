//go:build e2e

package tests

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/marcbran/arcourse/internal/arcourse"
	"github.com/marcbran/arcourse/internal/infra/broadcast"
	jsonfileinfra "github.com/marcbran/arcourse/internal/infra/jsonfile"
	jsonnetinfra "github.com/marcbran/arcourse/internal/infra/jsonnet"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	htmlplugin "github.com/marcbran/jsonnet-plugin-html/html"
)

const benchGraphTemplate = `
local a = import 'arcourse-ui/main.libsonnet';
local data = import 'data.jsonnet';

local siblingResources(n) = [
  [['kubernetes', '$context', 'resource' + std.toString(i)], { kind: 'Resource' + std.toString(i) }]
  for i in std.range(1, n)
];

local namespaceSiblings(n) = [
  [['kubernetes', '$context', '$namespace', 'nsresource' + std.toString(i)], { kind: 'NsResource' + std.toString(i) }]
  for i in std.range(1, n)
];

local podsSpec = [['kubernetes', '$context', 'pods'], a.table.node {
  data: data,
  linkSpecs:: [
    {
      at: ['items'],
      keys: [{ path: ['metadata', 'namespace'] }, { path: ['metadata', 'name'] }],
      value: [
        { const: 'kubernetes' },
        { origin: 'context' },
        { param: 'namespace', path: ['metadata', 'namespace'] },
        { param: 'pod', path: ['metadata', 'name'] },
      ],
    },
  ],
  table:: {
    at: ['items'],
    columns: [
      { label: 'Name', path: ['metadata', 'name'] },
      { label: 'Namespace', path: ['metadata', 'namespace'] },
      { label: 'Created', path: ['metadata', 'creationTimestamp'] },
    ],
  },
}];

local contextSpec = [['kubernetes', '$context'], {}];
local namespaceSpec = [['kubernetes', '$context', '$namespace'], {}];
local podDetailSpec = [['kubernetes', '$context', '$namespace', '$pod'], a.resource.node { data: {} }];

[
  [contextSpec, namespaceSpec, podDetailSpec, podsSpec] + siblingResources(100) + namespaceSiblings(30),
  a.default.view,
]
`

func benchPodsData(n int) string {
	var b strings.Builder
	b.WriteString("{ items: [\n")
	for i := 1; i <= n; i++ {
		fmt.Fprintf(&b, "  { metadata: { name: 'pod-%d', namespace: 'ns-%d', creationTimestamp: '2026-01-01T00:00:00Z' } },\n", i, i%20)
	}
	b.WriteString("] }\n")
	return b.String()
}

func newBenchFacade(b *testing.B, evaluateDir string, warm bool) pkg.Facade {
	b.Helper()
	pkgDir, err := filepath.Abs("../pkg")
	if err != nil {
		b.Fatal(err)
	}
	evaluator := jsonnetinfra.NewEvaluator(arcourse.Lib, []string{pkgDir}, []*jpoet.Plugin{htmlplugin.Plugin()})
	lastQuery := broadcast.NewLastQuery()
	auditRepo := jsonfileinfra.NewAuditRepo(b.TempDir())
	cfg := arcourse.Config{
		Root:  arcourse.RootConfig{Dir: evaluateDir, Mode: arcourse.ModeCompiledGraph},
		Audit: arcourse.AuditConfig{Formats: nil},
	}
	facade := arcourse.NewFacade(cfg, evaluator, lastQuery, auditRepo)
	if warm {
		err := facade.Warm(context.Background())
		if err != nil {
			b.Fatal(err)
		}
	}
	return facade
}

func BenchmarkQueryPodsTable(b *testing.B) {
	sizes := []int{100, 1000, 3000}
	formats := []pkg.Format{pkg.FormatJSON, pkg.FormatHTML}

	for _, warm := range []bool{false, true} {
		evaluateDir := b.TempDir()
		err := os.WriteFile(filepath.Join(evaluateDir, "root.jsonnet"), []byte(benchGraphTemplate), 0o600)
		if err != nil {
			b.Fatal(err)
		}
		facade := newBenchFacade(b, evaluateDir, warm)

		for _, n := range sizes {
			err := os.WriteFile(filepath.Join(evaluateDir, "data.jsonnet"), []byte(benchPodsData(n)), 0o600)
			if err != nil {
				b.Fatal(err)
			}
			for _, format := range formats {
				b.Run(fmt.Sprintf("warm=%t/n=%d/format=%s", warm, n, format), func(b *testing.B) {
					ctx := context.Background()
					b.ResetTimer()
					for i := 0; i < b.N; i++ {
						_, err := facade.Query(ctx, "root/kubernetes/context/demo/pods", nil, format)
						if err != nil {
							b.Fatal(err)
						}
					}
				})
			}
		}
	}
}
