const UNITS = [['w', 6048e5], ['d', 864e5], ['h', 36e5], ['m', 6e4], ['s', 1e3]];
const UNIT_MS = Object.fromEntries(UNITS);

function parseOffset(value) {
  const match = /^now(?:([+-])((?:\d+[smhdw])+))?$/.exec(value);
  if (!match) return null;
  if (!match[2]) return 0;
  let magnitude = 0;
  for (const [, amount, unit] of match[2].matchAll(/(\d+)([smhdw])/g)) {
    magnitude += parseInt(amount, 10) * UNIT_MS[unit];
  }
  return match[1] === '+' ? -magnitude : magnitude;
}

function resolve(value, nowMs) {
  const offset = parseOffset(value);
  if (offset !== null) return nowMs - offset;
  const parsed = Date.parse(value);
  return isNaN(parsed) ? nowMs : parsed;
}

function formatOffset(offsetMs) {
  if (offsetMs === 0) return 'now';
  if (offsetMs % 1000 !== 0) return null;
  const sign = offsetMs > 0 ? '-' : '+';
  let magnitude = Math.abs(offsetMs);
  let parts = '';
  for (const [unit, unitMs] of UNITS) {
    const count = Math.floor(magnitude / unitMs);
    if (count > 0) {
      parts += `${count}${unit}`;
      magnitude -= count * unitMs;
    }
  }
  return `now${sign}${parts}`;
}

function formatValue(originalValue, newEpochMs, nowMs) {
  if (parseOffset(originalValue) !== null) {
    const relative = formatOffset(nowMs - newEpochMs);
    if (relative !== null) return relative;
  }
  return new Date(Math.round(newEpochMs)).toISOString();
}

function clampToNow(from, to, nowMs) {
  if (to <= nowMs) return { from, to };
  const overshoot = to - nowMs;
  return { from: from - overshoot, to: to - overshoot };
}

function shiftRange(fromValue, toValue, direction, nowMs) {
  const from = resolve(fromValue, nowMs);
  const to = resolve(toValue, nowMs);
  const delta = (to - from) * direction;
  const clamped = clampToNow(from + delta, to + delta, nowMs);
  return {
    from: formatValue(fromValue, clamped.from, nowMs),
    to: formatValue(toValue, clamped.to, nowMs),
  };
}

function zoomOutRange(fromValue, toValue, nowMs) {
  const from = resolve(fromValue, nowMs);
  const to = resolve(toValue, nowMs);
  const delta = (to - from) / 2;
  const clamped = clampToNow(from - delta, to + delta, nowMs);
  return {
    from: formatValue(fromValue, clamped.from, nowMs),
    to: formatValue(toValue, clamped.to, nowMs),
  };
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

function formatLocal(epochMs) {
  const d = new Date(epochMs);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}

function formatLocalDate(epochMs) {
  return formatLocal(epochMs).slice(0, 10);
}

function displayValue(value, nowMs) {
  return parseOffset(value) === null ? formatLocal(resolve(value, nowMs)) : value;
}

function dateOnlyValue(value, nowMs) {
  return parseOffset(value) === null ? formatLocalDate(resolve(value, nowMs)) : '';
}

function combineDatePart(dateOnly, currentValue) {
  let timePart = '00:00:00';
  if (parseOffset(currentValue) === null) {
    const parsed = new Date(Date.parse(currentValue));
    if (!isNaN(parsed.getTime())) timePart = `${pad2(parsed.getHours())}:${pad2(parsed.getMinutes())}:${pad2(parsed.getSeconds())}`;
  }
  return `${dateOnly} ${timePart}`;
}

if (typeof HTMLElement !== 'undefined') {
  class TimeRangeNav extends HTMLElement {
    static get observedAttributes() {
      return ['from', 'to'];
    }

    connectedCallback() {
      this.attachShadow({ mode: 'open' });
      this.shadowRoot.innerHTML = `
        <style>
          :host {
            display: flex;
            justify-content: flex-end;
            font-family: monospace;
            font-size: 1.05em;
            margin-bottom: 0.75em;
          }
          .chip {
            display: flex;
            align-items: stretch;
            border: 1px solid var(--border-color);
            border-radius: 0.5em;
            overflow: hidden;
            background: var(--container-low-color);
          }
          .chip > * {
            display: flex;
            align-items: center;
            line-height: 1;
            padding: 0.4em 0.6em;
            border: none;
            border-right: 1px solid var(--border-color);
            border-radius: 0;
            background: transparent;
          }
          .chip > *:last-child {
            border-right: none;
          }
          .chip > button {
            width: 2.6rem;
            height: 2.6rem;
            padding: 0;
            justify-content: center;
            font-size: 2.1em;
            cursor: pointer;
          }
          #label {
            cursor: pointer;
            height: 2.6rem;
            padding-top: 0;
            padding-bottom: 0;
          }
          button, input[type="text"] {
            background: var(--background-color);
            color: inherit;
            border: 1px solid var(--border-color);
            border-radius: 0.3em;
            font: inherit;
            padding: 0.15em 0.5em;
          }
          button {
            cursor: pointer;
          }
          dialog {
            position: fixed;
            inset: auto;
            margin: 0;
            border: 1px solid var(--border-color);
            border-radius: 0.5em;
            padding: 1em 1.2em;
            background: var(--background-color);
            color: inherit;
            font-family: monospace;
            font-size: 0.9rem;
          }
          dialog::backdrop {
            background: transparent;
          }
          dialog button, dialog input[type="text"] {
            padding: 0.3em 0.6em;
          }
          dialog[open] {
            display: flex;
            flex-direction: column;
            gap: 0.75em;
          }
          dialog .row {
            display: flex;
            flex-direction: column;
            gap: 0.3em;
          }
          dialog .field {
            display: flex;
            gap: 0.3em;
          }
          dialog .field input[type="text"] {
            flex: 1;
            min-width: 13em;
          }
          dialog input:focus {
            outline: none;
          }
          dialog .date-wrap {
            position: relative;
            display: inline-flex;
          }
          dialog .date-btn {
            padding: 0.35em 0.5em;
            cursor: pointer;
          }
          dialog .date-wrap input[type="date"] {
            position: absolute;
            inset: 0;
            width: 100%;
            height: 100%;
            padding: 0;
            border: none;
            opacity: 0;
            pointer-events: none;
          }
          dialog .actions {
            display: flex;
            justify-content: flex-end;
            gap: 0.6em;
            margin-top: 0.75em;
          }
        </style>
        <div class="chip">
          <button id="back" type="button" title="Shift back">&laquo;</button>
          <span id="label" title="Edit time range"></span>
          <button id="forward" type="button" title="Shift forward">&raquo;</button>
          <button id="zoom-out" type="button" title="Zoom out">&#8854;</button>
        </div>
        <dialog id="modal">
          <div class="row">
            <label for="from-input">From</label>
            <div class="field">
              <input type="text" id="from-input">
              <div class="date-wrap">
                <button type="button" class="date-btn" id="from-date-btn" aria-label="Pick from date">&#128197;</button>
                <input type="date" id="from-date" tabindex="-1" aria-hidden="true">
              </div>
            </div>
          </div>
          <div class="row">
            <label for="to-input">To</label>
            <div class="field">
              <input type="text" id="to-input">
              <div class="date-wrap">
                <button type="button" class="date-btn" id="to-date-btn" aria-label="Pick to date">&#128197;</button>
                <input type="date" id="to-date" tabindex="-1" aria-hidden="true">
              </div>
            </div>
          </div>
          <div class="actions">
            <button type="button" id="apply">Apply</button>
          </div>
        </dialog>
      `;
      this.shadowRoot.getElementById('back').addEventListener('click', () => this.shift(-1));
      this.shadowRoot.getElementById('forward').addEventListener('click', () => this.shift(1));
      this.shadowRoot.getElementById('zoom-out').addEventListener('click', () => this.zoomOut());
      this.shadowRoot.getElementById('label').addEventListener('click', () => this.openModal());
      this.shadowRoot.getElementById('apply').addEventListener('click', () => this.applyModal());
      this.shadowRoot.getElementById('modal').addEventListener('click', (e) => {
        if (e.target === e.currentTarget) this.closeModal();
      });
      this.shadowRoot.getElementById('from-date').addEventListener('change', (e) => this.applyDatePart('from', e.target.value));
      this.shadowRoot.getElementById('to-date').addEventListener('change', (e) => this.applyDatePart('to', e.target.value));
      this.shadowRoot.getElementById('from-date-btn').addEventListener('click', () => this.shadowRoot.getElementById('from-date').showPicker());
      this.shadowRoot.getElementById('to-date-btn').addEventListener('click', () => this.shadowRoot.getElementById('to-date').showPicker());
      this.updateLabel();
    }

    attributeChangedCallback() {
      this.updateLabel();
    }

    updateLabel() {
      const label = this.shadowRoot && this.shadowRoot.getElementById('label');
      if (!label) return;
      const nowMs = Date.now();
      const from = displayValue(this.getAttribute('from'), nowMs);
      const to = displayValue(this.getAttribute('to'), nowMs);
      label.textContent = `${from} to ${to}`;
    }

    navigateTo(newFrom, newTo) {
      const url = new URL(window.location.href);
      url.searchParams.set('from', newFrom);
      url.searchParams.set('to', newTo);
      window.location.href = url.toString();
    }

    shift(direction) {
      const range = shiftRange(this.getAttribute('from'), this.getAttribute('to'), direction, Date.now());
      this.navigateTo(range.from, range.to);
    }

    zoomOut() {
      const range = zoomOutRange(this.getAttribute('from'), this.getAttribute('to'), Date.now());
      this.navigateTo(range.from, range.to);
    }

    openModal() {
      const nowMs = Date.now();
      this.shadowRoot.getElementById('from-input').value = displayValue(this.getAttribute('from'), nowMs);
      this.shadowRoot.getElementById('to-input').value = displayValue(this.getAttribute('to'), nowMs);
      this.shadowRoot.getElementById('from-date').value = dateOnlyValue(this.getAttribute('from'), nowMs);
      this.shadowRoot.getElementById('to-date').value = dateOnlyValue(this.getAttribute('to'), nowMs);
      const modal = this.shadowRoot.getElementById('modal');
      const rect = this.getBoundingClientRect();
      modal.style.top = `${rect.bottom + 4}px`;
      modal.style.right = `${window.innerWidth - rect.right}px`;
      modal.showModal();
    }

    closeModal() {
      this.shadowRoot.getElementById('modal').close();
    }

    applyDatePart(field, dateOnly) {
      if (!dateOnly) return;
      const input = this.shadowRoot.getElementById(`${field}-input`);
      input.value = combineDatePart(dateOnly, input.value);
    }

    applyModal() {
      const nowMs = Date.now();
      const fromValue = this.shadowRoot.getElementById('from-input').value;
      const toValue = this.shadowRoot.getElementById('to-input').value;
      const from = formatValue(fromValue, resolve(fromValue, nowMs), nowMs);
      const to = formatValue(toValue, resolve(toValue, nowMs), nowMs);
      this.navigateTo(from, to);
    }
  }

  customElements.define('time-range-nav', TimeRangeNav);
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { parseOffset, resolve, formatOffset, formatValue, shiftRange, zoomOutRange, formatLocal, formatLocalDate, displayValue, dateOnlyValue, combineDatePart };
}
