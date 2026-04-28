{
  apiSpec(spec): std.native('invoke:openapi')('apiSpec', [spec]),
  nestedSpec(spec): std.native('invoke:openapi')('nestedSpec', [spec]),
}
