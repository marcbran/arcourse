local compileGraph = import 'compile_graph.libsonnet';
local generateGraphRoot = import 'generate_graph_root.libsonnet';

function(entryPath, graphSpec)
  generateGraphRoot('import ' + std.escapeStringJson(entryPath), compileGraph(graphSpec))
