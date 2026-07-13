local collectNeighbors(obj, textPrefix='', exclude=[]) =
  std.flatMap(
    function(k)
      if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
      else
        local value = obj[k];
        local textPath = if textPrefix == '' then k else '%s/%s' % [textPrefix, k];
        if std.type(value) != 'object' then []
        else
          if std.objectHas(value, '_node') && std.objectHasAll(value, '_queryPath') then
            [{ link: value._queryPath, text: textPath }]
          else collectNeighbors(value, textPath, exclude),
    std.objectFields(obj)
  );

function(obj)
  local links = std.get(obj, 'links', {});
  local neighbors =
    (if std.type(links) == 'object' then collectNeighbors(links) else []) +
    collectNeighbors(obj, exclude=['data', '_view', 'links']);
  [
    'aside',
    { style: 'font-family: monospace' },
    [
      'nav',
      [
        'ul',
      ] + [
        ['li', ['a', { href: n.link, style: 'color: var(--primary-color)' }, n.text]]
        for n in neighbors
      ],
    ],
  ]
