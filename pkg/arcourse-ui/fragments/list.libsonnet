local h = import 'html/main.libsonnet';

local collectNeighbors(obj, textPrefix='', exclude=[]) =
  std.flatMap(
    function(k)
      if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
      else
        local value = obj[k];
        local textPath = if textPrefix == '' then k else '%s/%s' % [textPrefix, k];
        if std.type(value) != 'object' then []
        else
          if std.objectHas(value, '_node') && std.objectHasAll(value, '_urlPath') then
            [{ link: value._urlPath, text: textPath }]
          else collectNeighbors(value, textPath, exclude),
    std.objectFields(obj)
  );

function(obj)
  local links = std.get(obj, 'links', {});
  local neighbors =
    (if std.type(links) == 'object' then collectNeighbors(links) else []) +
    collectNeighbors(obj, exclude=['data', '_view', 'links']);
  h.aside([
  h.nav([
    h.ul([
      h.li([h.a({ href: n.link }, n.text)])
      for n in neighbors
    ]),
  ]),
])
