local truncateNode = import './truncate_node.libsonnet';

{
  output(input):: truncateNode(input, 'query'),
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
      name: 'descendant evalPath exposed in eval mode',
      input:: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _evalPath:: 'root.custom.path',
          value: 10,
        },
      },
      output(input)::
        local out = truncateNode(input, 'eval');
        local ref = out.child;
        {
          hasEvalPath: std.objectHas(ref, '_evalPath'),
          hasQueryPath: std.objectHas(ref, '_queryPath'),
          value: ref._evalPath,
        },
      expected: {
        hasEvalPath: true,
        hasQueryPath: false,
        value: 'root.custom.path',
      },
    },
    {
      name: 'descendant queryPath exposed in query mode',
      input:: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _queryPath:: '/root/custom/path',
          value: 10,
        },
      },
      output(input)::
        local out = truncateNode(input, 'query');
        local ref = out.child;
        {
          hasQueryPath: std.objectHas(ref, '_queryPath'),
          hasEvalPath: std.objectHas(ref, '_evalPath'),
          value: ref._queryPath,
        },
      expected: {
        hasQueryPath: true,
        hasEvalPath: false,
        value: '/root/custom/path',
      },
    },
    {
      name: 'evalPath hidden in query mode',
      input:: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _evalPath:: 'root.custom.path',
          _queryPath:: '/root/custom/path',
          value: 10,
        },
      },
      output(input)::
        local out = truncateNode(input, 'query');
        { hasEvalPath: std.objectHasAll(out.child, '_evalPath') },
      expected: {
        hasEvalPath: false,
      },
    },
    {
      name: 'queryPath hidden in eval mode',
      input:: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _evalPath:: 'root.custom.path',
          _queryPath:: '/root/custom/path',
          value: 10,
        },
      },
      output(input)::
        local out = truncateNode(input, 'eval');
        { hasQueryPath: std.objectHasAll(out.child, '_queryPath') },
      expected: {
        hasQueryPath: false,
      },
    },
    {
      name: 'params spec included in reference',
      input:: {
        _node: 'resource',
        child: {
          _node: 'facet',
          _params:: [{ name: 'page', type: 'number', default: 1 }],
          value: 10,
        },
      },
      output(input)::
        local out = truncateNode(input, 'query');
        local ref = out.child;
        {
          hasParamsSpec: std.objectHasAll(ref, '_params'),
          hasVisibleParamsSpec: std.objectHas(ref, '_params'),
          paramsSpec: ref._params,
        },
      expected: {
        hasParamsSpec: true,
        hasVisibleParamsSpec: false,
        paramsSpec: [{ name: 'page', type: 'number', default: 1 }],
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
