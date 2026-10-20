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

  at(links, k)::
    if std.isObject(links) && std.isString(k) then std.get(links, k, null)
    else if std.isArray(links) && std.isNumber(k) && k < std.length(links) then links[k]
    else null,

  href(target)::
    if std.isString(target) then target
    else if std.isObject(target) && std.objectHasAll(target, '_queryPath') then target._queryPath
    else null,

  link(target, children, style)::
    local href = c.href(target);
    if href == null then { element: 'span', attributes: { style: style }, children: children }
    else { element: 'a', attributes: { href: href, style: style }, children: children },

  key(k, target)::
    c.link(target, [k], 'color: var(--primary-color); font-weight: bold'),

  value(v, target)::
    if c.href(target) == null then c.scalar(v)
    else c.link(target, [c.scalar(v)], 'color: inherit'),

  isMultiline(v)::
    std.isString(v) && std.length(std.findSubstr('\n', v)) > 0,

  leaf:: {
    local l = self,
    prefix:: [],
    data:: error 'leaf requires data',
    target:: null,
    depth:: 0,
    html:
      if !c.isMultiline(l.data) then
        [{ element: 'div', children: l.prefix + [c.value(l.data, l.target)] }]
      else
        local trailing = std.length(l.data) - std.length(std.rstripChars(l.data, '\n'));
        local indicator = if trailing == 0 then '|-' else if trailing == 1 then '|' else '|+';
        local lines = std.split(if trailing > 0 then std.substr(l.data, 0, std.length(l.data) - 1) else l.data, '\n');
        [{ element: 'div', children: l.prefix + [indicator] }] + [
          { element: 'div', children: [c.indent(l.depth + 1), c.value(line, l.target)] }
          for line in lines
        ],
  },

  isLeaf(value)::
    !((std.type(value) == 'object' || std.type(value) == 'array') && std.length(value) > 0),

  mapLeaves(value, fn, path=[])::
    if c.isLeaf(value) then fn(path, value)
    else if std.isObject(value) then { [k]: c.mapLeaves(value[k], fn, path + [k]) for k in std.objectFields(value) }
    else [c.mapLeaves(value[i], fn, path + [i]) for i in std.range(0, std.length(value) - 1)],

  row(key, value, links, depth, bullet)::
    if !c.isLeaf(value) then
      [{ element: 'div', children: [
        c.indent(depth),
        bullet,
        c.key(key, null),
        ':',
      ] }] + c.children(value, links, depth + 1)
    else
      (c.leaf {
         prefix:: [
           c.indent(depth),
           bullet,
           c.key(key, c.at(links, 'key')),
           ': ',
         ],
         data:: value,
         target:: c.at(links, 'value'),
         depth:: depth,
       }).html,

  children(value, links, depth)::
    if std.type(value) == 'object' then
      std.flatMap(
        function(kv) c.row(kv.key, kv.value, c.at(links, kv.key), depth, ''),
        std.objectKeysValues(value)
      )
    else
      std.flatMap(
        function(i)
          local item = value[i];
          local itemLinks = c.at(links, i);
          if std.type(item) == 'object' then
            local kvs = std.objectKeysValues(item);
            c.row(kvs[0].key, kvs[0].value, c.at(itemLinks, kvs[0].key), depth, '- ') +
            std.flatMap(function(kv) c.row(kv.key, kv.value, c.at(itemLinks, kv.key), depth, '  '), kvs[1:])
          else
            (c.leaf {
               prefix:: [c.indent(depth), '- '],
               data:: item,
               target:: c.at(itemLinks, 'value'),
               depth:: depth,
             }).html,
        std.range(0, std.length(value) - 1)
      ),
};

local style = |||
  .yaml {
    white-space: pre-wrap;
    word-break: break-all;
  }
  .yaml a {
    text-decoration: none;
  }
  .yaml a:hover {
    text-decoration: underline;
  }
|||;

{
  local c = self,
  data:: error 'Yaml requires data',
  embeddedLinks:: null,
  mapLeaves(value, fn):: yaml.mapLeaves(value, fn),
  html: [
    { element: 'style', children: [style] },
    { element: 'pre', attributes: { class: 'yaml card' }, children: yaml.children(c.data, c.embeddedLinks, 0) },
  ],
}
