local h = import 'html/main.libsonnet';

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
    h.span({ style: 'color: var(--primary-color); font-weight: bold' }, [k]),

  row(key, value, depth, bullet)::
    local hasChildren =
      (std.type(value) == 'object' || std.type(value) == 'array')
      && std.length(value) > 0;
    if hasChildren then
      [h.div({}, [
        self.indent(depth), bullet, self.key(key), ':',
      ])] + self.children(value, depth + 1)
    else
      [h.div({}, [
        self.indent(depth), bullet, self.key(key), ': ' + self.scalar(value),
      ])],

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
          [h.div({}, [
            self.indent(depth), '- ' + self.scalar(item),
          ])]
      , value),
};

function(value) h.pre(yaml.children(value, 0))
