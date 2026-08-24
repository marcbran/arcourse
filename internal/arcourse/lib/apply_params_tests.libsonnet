local applyParams = import './apply_params.libsonnet';

local nodeWithParams(params, extra={}) = {
  _node: true,
  _paramSpecs: params,
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
        _paramSpecs: [{ name: 'filter', type: 'string' }],
        _params: { filter: 'active' },
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
        _paramSpecs: [{ name: 'page', type: 'number', default: 1 }],
        _params: { page: 2 },
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
        _paramSpecs: [{ name: 'enabled', type: 'boolean' }],
        _params: { enabled: true },
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
        _paramSpecs: [{ name: 'tags', type: 'array', items: 'string' }],
        _params: { tags: ['a', 'b'] },
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
        _paramSpecs: [{ name: 'ids', type: 'array', items: 'number' }],
        _params: { ids: [1, 2] },
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
        _paramSpecs: [{ name: 'ids', type: 'array', items: 'number' }],
        _params: { ids: [1, 2] },
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
        _paramSpecs: [{ name: 'page', type: 'number' }],
        _params: { page: 2 },
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
        _paramSpecs: [{ name: 'page', type: 'number', default: 1 }],
        _params: { page: 1 },
      },
    },
    {
      name: 'unset optional param with a null default is omitted from _params',
      input:: {
        node: nodeWithParams([
          { name: 'severity', type: 'string', default: null },
          { name: 'page', type: 'number', default: 1 },
        ]),
        params: {},
      },
      expected: {
        _node: true,
        _paramSpecs: [
          { name: 'severity', type: 'string', default: null },
          { name: 'page', type: 'number', default: 1 },
        ],
        _params: { page: 1 },
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
        _paramSpecs: [{ name: 'pageSize', type: 'number' }],
        _params: { pageSize: 100 },
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
        _paramSpecs: [
          { name: 'page', type: 'number', default: 1 },
          { name: 'pageSize', type: 'number' },
        ],
        _params: { page: 1, pageSize: 50 },
      },
    },
  ],
}
