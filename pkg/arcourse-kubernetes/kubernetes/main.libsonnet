{
  contexts(): std.native('invoke:kubernetes')('contexts', []),
  get(ctx, path): std.native('invoke:kubernetes')('get', [ctx, path]),
  neat: {
    get(ctx, path):
      local result = $.get(ctx, path);
      if std.objectHas(result, 'items') then
        result {
          items: [
            item { metadata+: { managedFields:: [] } }
            for item in super.items
          ],
        }
      else
        result {
          metadata+: {
            managedFields:: [],
          },
        },
  },
}
