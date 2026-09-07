const test = require('node:test');
const assert = require('node:assert/strict');
const { resolve, formatOffset, shiftRange, zoomOutRange, formatLocal, formatLocalDate, displayValue, dateOnlyValue, combineDatePart } = require('./time-range-nav.js');

const NOW = Date.parse('2026-08-11T12:00:00Z');

const resolveCases = [
  { name: 'bare now', value: 'now', want: NOW },
  { name: 'relative minutes', value: 'now-15m', want: NOW - 15 * 60e3 },
  { name: 'relative hours', value: 'now-6h', want: NOW - 6 * 3600e3 },
  { name: 'relative days', value: 'now-7d', want: NOW - 7 * 86400e3 },
  { name: 'relative weeks', value: 'now-2w', want: NOW - 2 * 604800e3 },
  { name: 'relative future', value: 'now+1h', want: NOW + 3600e3 },
  { name: 'compound relative', value: 'now-2h30m', want: NOW - (2 * 3600e3 + 30 * 60e3) },
  { name: 'RFC3339 string', value: '2026-08-04T00:00:00.000Z', want: Date.parse('2026-08-04T00:00:00.000Z') },
  { name: 'garbage falls back to now', value: 'not-a-time', want: NOW },
];

test('resolve', async (t) => {
  for (const c of resolveCases) {
    await t.test(c.name, () => {
      assert.equal(resolve(c.value, NOW), c.want);
    });
  }
});

const formatOffsetCases = [
  { name: 'zero is now', offsetMs: 0, want: 'now' },
  { name: 'exact hours', offsetMs: 6 * 3600e3, want: 'now-6h' },
  { name: 'exact weeks', offsetMs: 2 * 604800e3, want: 'now-2w' },
  { name: 'negative is future', offsetMs: -3600e3, want: 'now+1h' },
  { name: 'breaks down into minutes and seconds', offsetMs: 90e3, want: 'now-1m30s' },
  { name: 'breaks down into hours and minutes', offsetMs: 150 * 60e3, want: 'now-2h30m' },
  { name: 'breaks down every unit at once', offsetMs: 8 * 604800e3 + 3 * 864e5 + 4 * 36e5 + 5 * 6e4 + 6e3, want: 'now-8w3d4h5m6s' },
  { name: 'sub-second magnitude has no relative form', offsetMs: 1500, want: null },
];

test('formatOffset', async (t) => {
  for (const c of formatOffsetCases) {
    await t.test(c.name, () => {
      assert.equal(formatOffset(c.offsetMs), c.want);
    });
  }
});

const shiftRangeCases = [
  {
    name: 'relative values stay relative with an updated offset',
    from: 'now-6h', to: 'now', direction: -1,
    want: { from: 'now-12h', to: 'now-6h' },
  },
  {
    name: 'backward shift is unaffected by the now clamp',
    from: 'now-6h', to: 'now', direction: -1,
    want: { from: 'now-12h', to: 'now-6h' },
  },
  {
    name: 'forward shift is a no-op when already at now',
    from: 'now-6h', to: 'now', direction: 1,
    want: { from: 'now-6h', to: 'now' },
  },
  {
    name: 'forward shift still clamps to now when it would overshoot',
    from: 'now-6h', to: 'now-1h', direction: 1,
    want: { from: 'now-5h', to: 'now' },
  },
  {
    name: 'absolute values stay absolute',
    from: '2026-08-04T00:00:00.000Z', to: '2026-08-04T06:00:00.000Z', direction: 1,
    want: { from: '2026-08-04T06:00:00.000Z', to: '2026-08-04T12:00:00.000Z' },
  },
];

test('shiftRange', async (t) => {
  for (const c of shiftRangeCases) {
    await t.test(c.name, () => {
      assert.deepEqual(shiftRange(c.from, c.to, c.direction, NOW), c.want);
    });
  }

  await t.test('mixed - each field keeps its own kind independently', () => {
    const result = shiftRange('now-6h', '2026-08-11T18:00:00.000Z', 1, NOW);
    assert.match(result.from, /^now(?:[+-](?:\d+[smhdw])+)?$/);
    assert.match(result.to, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
  });
});

const zoomOutRangeCases = [
  {
    name: 'not at now extends both sides equally',
    from: 'now-12h', to: 'now-6h',
    want: { from: 'now-15h', to: 'now-3h' },
  },
  {
    name: 'at now extends only the from side, to stays pinned',
    from: 'now-6h', to: 'now',
    want: { from: 'now-12h', to: 'now' },
  },
];

test('zoomOutRange', async (t) => {
  for (const c of zoomOutRangeCases) {
    await t.test(c.name, () => {
      assert.deepEqual(zoomOutRange(c.from, c.to, NOW), c.want);
    });
  }
});

const formatLocalCases = [
  { name: 'pads single digits', epochMs: new Date(2026, 0, 5, 3, 4, 5).getTime(), want: '2026-01-05 03:04:05' },
  { name: 'no padding needed', epochMs: new Date(2026, 7, 4, 14, 30, 45).getTime(), want: '2026-08-04 14:30:45' },
];

test('formatLocal', async (t) => {
  for (const c of formatLocalCases) {
    await t.test(c.name, () => {
      assert.equal(formatLocal(c.epochMs), c.want);
    });
  }
});

const formatLocalDateCases = [
  { name: 'drops the time-of-day', epochMs: new Date(2026, 0, 5, 3, 4, 5).getTime(), want: '2026-01-05' },
];

test('formatLocalDate', async (t) => {
  for (const c of formatLocalDateCases) {
    await t.test(c.name, () => {
      assert.equal(formatLocalDate(c.epochMs), c.want);
    });
  }
});

const displayValueCases = [
  { name: 'relative stays as-is', value: 'now-6h', want: 'now-6h' },
  { name: 'absolute formats to local', value: '2026-08-04T00:00:00Z', want: formatLocal(Date.parse('2026-08-04T00:00:00Z')) },
];

test('displayValue', async (t) => {
  for (const c of displayValueCases) {
    await t.test(c.name, () => {
      assert.equal(displayValue(c.value, NOW), c.want);
    });
  }
});

const dateOnlyValueCases = [
  { name: 'relative has no single date - blank', value: 'now-6h', want: '' },
  { name: 'absolute gives its local date', value: '2026-08-04T00:00:00Z', want: formatLocalDate(Date.parse('2026-08-04T00:00:00Z')) },
];

test('dateOnlyValue', async (t) => {
  for (const c of dateOnlyValueCases) {
    await t.test(c.name, () => {
      assert.equal(dateOnlyValue(c.value, NOW), c.want);
    });
  }
});

const combineDatePartCases = [
  {
    name: 'relative current value - defaults to midnight',
    dateOnly: '2026-08-04', currentValue: 'now-6h',
    want: '2026-08-04 00:00:00',
  },
  {
    name: 'absolute current value - preserves its time-of-day',
    dateOnly: '2026-08-04', currentValue: formatLocal(new Date(2026, 7, 1, 14, 30, 0).getTime()),
    want: '2026-08-04 14:30:00',
  },
  {
    name: 'unparseable current value - defaults to midnight',
    dateOnly: '2026-08-04', currentValue: '',
    want: '2026-08-04 00:00:00',
  },
];

test('combineDatePart', async (t) => {
  for (const c of combineDatePartCases) {
    await t.test(c.name, () => {
      assert.equal(combineDatePart(c.dateOnly, c.currentValue), c.want);
    });
  }
});
