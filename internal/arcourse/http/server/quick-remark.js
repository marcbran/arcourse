(function () {
  if (typeof HTMLElement === 'undefined') return;

  function deepActiveElement() {
    var el = document.activeElement;
    while (el && el.shadowRoot && el.shadowRoot.activeElement) el = el.shadowRoot.activeElement;
    return el;
  }

  function isEditable(el) {
    var tag = el && el.tagName;
    return tag === 'INPUT' || tag === 'TEXTAREA' || (el && el.isContentEditable);
  }

  var template = `
    <style>
      :host { font-family: monospace; }
      dialog {
        border: 1px solid var(--border-color);
        border-radius: 0.5em;
        background: var(--background-color);
        color: var(--on-background-color);
        padding: 0;
        width: min(90vw, 42em);
        margin-top: 12vh;
        box-shadow: 0 0.5em 2em rgba(0, 0, 0, 0.35);
      }
      dialog::backdrop { background: rgba(0, 0, 0, 0.4); }
      textarea {
        display: block;
        width: 100%;
        box-sizing: border-box;
        font: inherit;
        padding: 0.6em 0.75em;
        border: none;
        border-bottom: 1px solid var(--border-color);
        background: transparent;
        color: inherit;
        outline: none;
        resize: vertical;
      }
      .footer {
        display: flex;
        justify-content: space-between;
        gap: 1em;
        padding: 0.35em 0.75em;
        font-size: 0.85em;
      }
      .hint { opacity: 0.5; }
      .error { color: light-dark(#a1260d, #f48771); }
    </style>
    <dialog part="modal">
      <textarea rows="5" spellcheck="true" placeholder="Remark…"></textarea>
      <div class="footer">
        <span class="error"></span>
        <span class="hint">⌘↵ save · esc close</span>
      </div>
    </dialog>
  `;

  class QuickRemark extends HTMLElement {
    connectedCallback() {
      if (!this.shadowRoot) this.attachShadow({ mode: 'open' });
      this.shadowRoot.innerHTML = template;
      this.modal = this.shadowRoot.querySelector('dialog');
      this.input = this.shadowRoot.querySelector('textarea');
      this.error = this.shadowRoot.querySelector('.error');

      this.input.addEventListener('keydown', this.onKeydown.bind(this));
      this.modal.addEventListener('click', function (e) {
        if (e.target === this.modal) this.modal.close();
      }.bind(this));

      if (!window.__quickRemarkBound) {
        window.__quickRemarkBound = true;
        document.addEventListener('keydown', function (e) {
          if (e.key !== 'r' || e.metaKey || e.ctrlKey || e.altKey) return;
          if (isEditable(deepActiveElement())) return;
          var remark = document.querySelector('quick-remark');
          if (remark && !remark.isOpen()) {
            e.preventDefault();
            remark.openModal();
          }
        }, true);
      }
    }

    isOpen() {
      return !!(this.modal && this.modal.open);
    }

    openModal() {
      this.error.textContent = '';
      this.modal.showModal();
      this.input.focus();
    }

    onKeydown(e) {
      if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        this.submit();
      }
    }

    submit() {
      var text = this.input.value;
      var from = this.getAttribute('from');
      if (!text.trim() || !from || this.input.disabled) return;
      this.input.disabled = true;
      this.error.textContent = '';
      fetch('/api/remark/' + encodeURIComponent(from), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: text }),
      })
        .then(function (resp) {
          return resp.json().then(function (body) {
            if (!resp.ok) throw new Error(body.message || 'http ' + resp.status);
          });
        })
        .then(function () {
          this.input.value = '';
          this.modal.close();
        }.bind(this))
        .catch(function (err) {
          this.error.textContent = err.message;
        }.bind(this))
        .finally(function () {
          this.input.disabled = false;
          if (this.isOpen()) this.input.focus();
        }.bind(this));
    }
  }

  if (!customElements.get('quick-remark')) customElements.define('quick-remark', QuickRemark);
})();
