local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-course',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'arcourse/arcourse-course',
  path: 'arcourse/arcourse-course',
  target: 'arcourse-course',
}, |||
  Node specs exposing an arcourse instance's own course history as part of the graph
  it describes.

  Reads the course log through the built-in arcourse plugin, so the sessions list, a
  session's course and a single visit are ordinary traversable nodes rather than a
  separate page. Watching a session streams new visits as they are appended.
|||, {})
