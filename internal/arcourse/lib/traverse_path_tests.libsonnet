local traversePath = import './traverse_path.libsonnet';

{
  output(input):: traversePath(input.obj, input.path),
  tests: [
    {
      name: 'empty path returns object',
      input:: {
        obj: { value: 42 },
        path: [],
      },
      expected: { value: 42 },
    },
    {
      name: 'single plain field',
      input:: {
        obj: { child: { value: 1 } },
        path: ['child'],
      },
      expected: { value: 1 },
    },
    {
      name: 'nested plain fields',
      input:: {
        obj: { a: { b: { value: 2 } } },
        path: ['a', 'b'],
      },
      expected: { value: 2 },
    },
    {
      name: 'function field applied to next segment',
      input:: {
        obj: { greet: function(name) { message: 'hello ' + name } },
        path: ['greet', 'world'],
      },
      expected: { message: 'hello world' },
    },
    {
      name: 'chained function fields',
      input:: {
        obj: {
          owner: function(o) {
            repo: function(r) { full: o + '/' + r },
          },
        },
        path: ['owner', 'marcbran', 'repo', 'arcourse'],
      },
      expected: { full: 'marcbran/arcourse' },
    },
    {
      name: 'mixed plain and function fields',
      input:: {
        obj: {
          repos: {
            owner: function(o) {
              repo: function(r) { name: o + '/' + r },
            },
          },
        },
        path: ['repos', 'owner', 'marcbran', 'repo', 'arcourse'],
      },
      expected: { name: 'marcbran/arcourse' },
    },
  ],
}
