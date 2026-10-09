local yaml = import 'yaml.libsonnet';

local anchors(v) =
  if std.isObject(v) then
    (if std.get(v, 'element', null) == 'a' then [{ text: v.children[0], href: v.attributes.href }] else [])
    + std.flattenArrays([anchors(v[k]) for k in std.objectFields(v)])
  else if std.isArray(v) then std.flattenArrays([anchors(x) for x in v])
  else [];

{
  output(input):: input(),
  tests: [
    {
      name: 'yaml links leaf keys and values from embeddedLinks given as node refs or strings',
      input:: function()
        anchors((yaml {
                   data:: { a: 'x', b: { c: 'y' } },
                   embeddedLinks:: {
                     a: { key: { _node: true, _queryPath: '/root/a' } },
                     b: { c: { value: 'https://docs.example.com' } },
                   },
                 }).html),
      expected: [
        { text: 'a', href: '/root/a' },
        { text: 'y', href: 'https://docs.example.com' },
      ],
    },
    {
      name: 'yaml embeddedLinks follow arrays by index with null for unlinked items',
      input:: function()
        anchors((yaml {
                   data:: { tags: ['t1', 't2'] },
                   embeddedLinks:: { tags: [null, { value: '/root/t2' }] },
                 }).html),
      expected: [{ text: 't2', href: '/root/t2' }],
    },
    {
      name: 'yaml embeddedLinks only apply at leaf positions, a non-leaf position mirrors its children',
      input:: function()
        anchors((yaml {
                   data:: { b: { c: 'y' } },
                   embeddedLinks:: { b: { key: '/root/b' } },
                 }).html),
      expected: [],
    },
    {
      name: 'yaml mapLeaves passes full paths and treats empty containers as leaves',
      input:: function()
        yaml.mapLeaves({ a: { b: 1 }, l: [2], e: {} }, function(path, value) path),
      expected: { a: { b: ['a', 'b'] }, l: [['l', 0]], e: ['e'] },
    },
  ],
}
