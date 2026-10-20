{
  now(): std.native('invoke:time')('now', []),
  addDuration(epochMs, spec): std.native('invoke:time')('addDuration', [epochMs, spec]),
  parse(value, layout): std.native('invoke:time')('parse', [value, layout]),
  format(epochMs, layout): std.native('invoke:time')('format', [epochMs, layout]),
}
