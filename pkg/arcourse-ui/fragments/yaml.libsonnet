local yaml = {
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
    local indentStr = self.indent(depth);
    local keyNode = self.key(key);
    local scalarStr = self.scalar(value);
    if hasChildren then
      [{ element: 'div', children: [
        indentStr, bullet, keyNode, ':',
      ] }] + self.children(value, depth + 1)
    else
      [{ element: 'div', children: [
        indentStr, bullet, keyNode, ': ' + scalarStr,
      ] }],

  children(value, depth)::
    if std.type(value) == 'object' then
      std.flatMap(
        function(kv) self.row(kv.key, kv.value, depth, ''),
        std.objectKeysValues(value)
      )
    else
      std.flatMap(function(item)
        if std.type(item) == 'object' then
          local kvs = std.objectKeysValues(item);
          self.row(kvs[0].key, kvs[0].value, depth, '- ') +
          std.flatMap(function(kv) self.row(kv.key, kv.value, depth, '  '), kvs[1:])
        else
          local indentStr = self.indent(depth);
          local scalarStr = self.scalar(item);
          [{ element: 'div', children: [
            indentStr, '- ' + scalarStr,
          ] }]
      , value),
};

function(value) { element: 'pre', children: yaml.children(value, 0) }
