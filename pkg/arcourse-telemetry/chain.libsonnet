local root = import 'root';

local capitalize(s) = std.asciiUpper(s[0:1]) + s[1:];
local eqMatcher(label, var) = label + '="%(' + var + ')s"';
local excludeMatcher(label) = label + '!=""';
local matcherClause(parts) = std.join(', ', parts);
local promote(arr, idx, val) = arr[:idx] + [val] + arr[idx + 1:];

local chain(node, calls) = std.foldl(function(n, call) n[call[0]](call[1]), calls, node);
local chainFields(node, fields) = std.foldl(function(n, f) n[f], fields, node);

local accs(names, vars) =
  local n = std.length(names);
  local initialMatchers = [excludeMatcher(name) for name in names];
  std.foldl(
    function(acc, i)
      acc + [
        if i == 0 then { ancestorVars: [], matchers: initialMatchers } else
          local prev = acc[i - 1];
          {
            ancestorVars: prev.ancestorVars + [vars[i - 1]],
            matchers: promote(prev.matchers, i - 1, eqMatcher(names[i - 1], vars[i - 1])),
          },
      ],
    std.range(0, n),
    []
  );

{
  root: root,
  capitalize: capitalize,
  eqMatcher: eqMatcher,
  excludeMatcher: excludeMatcher,
  matcherClause: matcherClause,
  promote: promote,
  chain: chain,
  chainFields: chainFields,
  accs: accs,
}
