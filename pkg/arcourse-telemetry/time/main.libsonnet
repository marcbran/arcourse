{
  now(): std.native('invoke:time')('now', []),
  addDuration(epochMs, spec): std.native('invoke:time')('addDuration', [epochMs, spec]),
  parseRFC3339(value): std.native('invoke:time')('parseRFC3339', [value]),
}
