package arcourse

import "embed"

//go:embed lib/*.libsonnet lib/arcourse-graph/*.libsonnet lib/arcourse-ui/*.libsonnet lib/arcourse-ui/*.js
var Lib embed.FS
