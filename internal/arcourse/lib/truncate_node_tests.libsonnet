local truncateNode = import './truncate_node.libsonnet';

{
  output(input):: truncateNode(input),
  tests: [
    {
      name: 'plain object no node',
      input:: {
        name: 'plain',
        nested: {
          count: 1,
          values: [1, 2, 3],
        },
      },
      expected: {
        name: 'plain',
        nested: {
          count: 1,
          values: [1, 2, 3],
        },
      },
    },
    {
      name: 'root node kept',
      input:: {
        _node: 'resource',
        name: 'root',
      },
      expected: {
        _node: 'resource',
        name: 'root',
      },
    },
    {
      name: 'descendant node truncated',
      input:: {
        _node: 'resource',
        child: {
          _node: 'facet',
          value: 10,
        },
      },
      expected: {
        _node: 'resource',
        child: {
          _node: 'facet',
        },
      },
    },
    {
      name: 'descendant path preserved',
      input:: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _path: 'custom.path',
          value: 10,
        },
      },
      expected: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _path: 'custom.path',
        },
      },
    },
    {
      name: 'descendant url path preserved',
      input:: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _urlPath: 'root/custom/url/path',
          value: 10,
        },
      },
      expected: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _urlPath: 'root/custom/url/path',
        },
      },
    },
    {
      name: 'summary included',
      input:: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _summary: 'summary text',
          value: 10,
        },
      },
      expected: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _summary: 'summary text',
        },
      },
    },
    {
      name: 'summary absent',
      input:: {
        _node: 'resource',
        child: {
          _node: 'facet',
          value: 10,
        },
      },
      expected: {
        _node: 'resource',
        child: {
          _node: 'facet',
        },
      },
    },
    {
      name: 'deep nesting truncates descendant nodes',
      input:: {
        _node: 'resource',
        metadata: {
          region: 'us-east-1',
          groups: {
            selected: {
              _node: 'facet',
              data: {
                enabled: true,
              },
            },
          },
        },
      },
      expected: {
        _node: 'resource',
        metadata: {
          region: 'us-east-1',
          groups: {
            selected: {
              _node: 'facet',
            },
          },
        },
      },
    },
    {
      name: 'functions stripped',
      input:: {
        _node: 'resource',
        label: 'keep',
        build: function(x) x + 1,
        nested: {
          keep: true,
          skip: function() 42,
        },
      },
      expected: {
        _node: 'resource',
        label: 'keep',
        nested: {
          keep: true,
        },
      },
    },
    {
      name: 'circular reference through nodes',
      input::
        local x = {
          _node: 'resource',
          child: {
            _node: 'resource',
            back: x,
          },
        };
        x,
      expected: {
        _node: 'resource',
        child: {
          _node: 'resource',
        },
      },
    },
    {
      name: 'array descendants truncated',
      input:: {
        _node: 'resource',
        items: [
          {
            _node: 'facet',
            value: 1,
          },
          {
            keep: true,
          },
          {
            _node: 'facet',
            _summary: 'second',
            value: 2,
          },
        ],
      },
      expected: {
        _node: 'resource',
        items: [
          {
            _node: 'facet',
          },
          {
            keep: true,
          },
          {
            _node: 'facet',
            _summary: 'second',
          },
        ],
      },
    },
  ],
}
