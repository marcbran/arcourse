local yaml = {
  local c = self,

  indent(depth)::
    std.join('', std.makeArray(depth * 2, function(_) ' ')),

  scalar(v)::
    if std.type(v) == 'null' then 'null'
    else if std.type(v) == 'boolean' then (if v then 'true' else 'false')
    else if std.type(v) == 'object' then '{}'
    else if std.type(v) == 'array' then '[]'
    else '%s' % v,

  key(k)::
    { element: 'span', attributes: { style: 'color: var(--primary-color); font-weight: bold' }, children: [k] },

  row(key, value, depth, bullet)::
    local hasChildren =
      (std.type(value) == 'object' || std.type(value) == 'array')
      && std.length(value) > 0;
    if hasChildren then
      [{ element: 'div', children: [
        c.indent(depth), bullet, c.key(key), ':',
      ] }] + c.children(value, depth + 1)
    else
      [{ element: 'div', children: [
        c.indent(depth), bullet, c.key(key), ': ' + c.scalar(value),
      ] }],

  children(value, depth)::
    if std.type(value) == 'object' then
      std.flatMap(
        function(kv) c.row(kv.key, kv.value, depth, ''),
        std.objectKeysValues(value)
      )
    else
      std.flatMap(function(item)
        if std.type(item) == 'object' then
          local kvs = std.objectKeysValues(item);
          c.row(kvs[0].key, kvs[0].value, depth, '- ') +
          std.flatMap(function(kv) c.row(kv.key, kv.value, depth, '  '), kvs[1:])
        else
          [{ element: 'div', children: [
            c.indent(depth), '- ' + c.scalar(item),
          ] }]
      , value),
};

{
  local c = self,
  data:: error 'Yaml requires data',
  html: { element: 'pre', children: yaml.children(c.data, 0) },
}
