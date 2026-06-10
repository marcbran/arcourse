local applyParams = import './apply_params.libsonnet';

local nodeWithParams(params, extra={}) = {
  _node: true,
  _params:: params,
} + extra;

{
  output(input):: applyParams(input.node, input.params),
  tests: [
    {
      name: 'node without params passes through',
      input:: {
        node: { _node: true, value: 1 },
        params: {},
      },
      expected: { _node: true, value: 1 },
    },
    {
      name: 'string param applied verbatim',
      input:: {
        node: nodeWithParams([{ name: 'filter', type: 'string' }]),
        params: { filter: 'active' },
      },
      expected: {
        _node: true,
        filter: 'active',
      },
    },
    {
      name: 'number param parsed from json',
      input:: {
        node: nodeWithParams([{ name: 'page', type: 'number', default: 1 }]),
        params: { page: '2' },
      },
      expected: {
        _node: true,
        page: 2,
      },
    },
    {
      name: 'boolean param parsed from json',
      input:: {
        node: nodeWithParams([{ name: 'enabled', type: 'boolean' }]),
        params: { enabled: 'true' },
      },
      expected: {
        _node: true,
        enabled: true,
      },
    },
    {
      name: 'array param parsed and coerced',
      input:: {
        node: nodeWithParams([{ name: 'tags', type: 'array', items: 'string' }]),
        params: { tags: '["a","b"]' },
      },
      expected: {
        _node: true,
        tags: ['a', 'b'],
      },
    },
    {
      name: 'array param accepts native json array',
      input:: {
        node: nodeWithParams([{ name: 'ids', type: 'array', items: 'number' }]),
        params: { ids: [1, 2] },
      },
      expected: {
        _node: true,
        ids: [1, 2],
      },
    },
    {
      name: 'array param coerces repeated raw values',
      input:: {
        node: nodeWithParams([{ name: 'ids', type: 'array', items: 'number' }]),
        params: { ids: ['1', '2'] },
      },
      expected: {
        _node: true,
        ids: [1, 2],
      },
    },
    {
      name: 'number param accepts native json number',
      input:: {
        node: nodeWithParams([{ name: 'page', type: 'number' }]),
        params: { page: 2 },
      },
      expected: {
        _node: true,
        page: 2,
      },
    },
    {
      name: 'optional param falls back to default',
      input:: {
        node: nodeWithParams([{ name: 'page', type: 'number', default: 1 }]),
        params: {},
      },
      expected: {
        _node: true,
        page: 1,
      },
    },
    {
      name: 'required param provided',
      input:: {
        node: nodeWithParams([{ name: 'pageSize', type: 'number' }]),
        params: { pageSize: '100' },
      },
      expected: {
        _node: true,
        pageSize: 100,
      },
    },
    {
      name: 'multiple params resolved together',
      input:: {
        node: nodeWithParams([
          { name: 'page', type: 'number', default: 1 },
          { name: 'pageSize', type: 'number' },
        ]),
        params: { pageSize: '50' },
      },
      expected: {
        _node: true,
        page: 1,
        pageSize: 50,
      },
    },
    {
      name: 'params spec remains on node',
      input:: {
        node: nodeWithParams([{ name: 'page', type: 'number', default: 1 }]),
        params: { page: '3' },
      },
      output(input)::
        local result = applyParams(input.node, input.params);
        {
          page: result.page,
          hasParamsSpec: std.objectHasAll(result, '_params'),
          paramsSpec: result._params,
        },
      expected: {
        page: 3,
        hasParamsSpec: true,
        paramsSpec: [{ name: 'page', type: 'number', default: 1 }],
      },
    },
  ],
}
