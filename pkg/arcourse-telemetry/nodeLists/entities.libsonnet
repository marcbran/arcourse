function(entity)
  function(specs)
    std.flattenArrays([entity(spec) for spec in specs])
