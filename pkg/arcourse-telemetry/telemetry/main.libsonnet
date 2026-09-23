{
  query(items): std.native('invoke:telemetry')('query', [items]),
  fetch(type, datasource, id): std.native('invoke:telemetry')('fetch', [type, datasource, id]),
}
