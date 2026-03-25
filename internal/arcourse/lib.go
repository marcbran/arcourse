package arcourse

import "embed"

//go:embed lib/*.libsonnet
var Lib embed.FS
