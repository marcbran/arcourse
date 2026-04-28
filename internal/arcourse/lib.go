package arcourse

import "embed"

//go:embed lib/*.libsonnet lib/arcourse-graph/*.libsonnet
var Lib embed.FS
