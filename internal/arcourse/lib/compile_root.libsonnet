local compileGraph = import 'compile_graph.libsonnet';

function(entryPath, graphSpec)
  local compiledShape = compileGraph(graphSpec);
  |||
    local construct_compiled_graph_root = import 'lib/construct_compiled_graph_root.libsonnet';
    construct_compiled_graph_root(import '%s', %s)
  ||| % [entryPath, std.manifestJson(compiledShape)]
