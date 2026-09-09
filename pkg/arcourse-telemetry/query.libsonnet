function(time, telemetry)
  local resolveTime(nowMs, value) =
    if value == 'now' then std.toString(nowMs)
    else if std.length(value) > 3 && std.substr(value, 0, 3) == 'now' then
      std.toString(time.addDuration(nowMs, std.substr(value, 3, std.length(value) - 3)))
    else
      std.toString(time.parseRFC3339(value));

  function(datasource, items, from='now-1h', to='now')
    local nowMs = time.now();
    local resolvedFrom = resolveTime(nowMs, from);
    local resolvedTo = resolveTime(nowMs, to);
    telemetry.query([
      item { datasource: datasource, from: resolvedFrom, to: resolvedTo }
      for item in items
    ])
