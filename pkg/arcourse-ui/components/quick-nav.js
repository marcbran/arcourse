(function () {
  if (typeof HTMLElement === 'undefined') return;

  var GROUPS = [
    { key: 'breadcrumbs', title: 'breadcrumbs' },
    { key: 'links', title: 'links' },
    { key: 'table', title: 'table' },
  ];

  function scrapeItems() {
    var items = [];
    document.querySelectorAll('.breadcrumbs a[href]').forEach(function (a) {
      var text = a.textContent.trim();
      if (text) items.push({ text: text, link: a.href, group: 'breadcrumbs' });
    });
    document.querySelectorAll('.list a[href]').forEach(function (a) {
      var text = a.textContent.trim();
      if (text) items.push({ text: text, link: a.href, group: 'links' });
    });
    document.querySelectorAll('.table tbody tr').forEach(function (tr) {
      var a = tr.querySelector('a[href]');
      if (!a) return;
      var text = Array.prototype.map
        .call(tr.querySelectorAll('td'), function (td) { return td.textContent.trim(); })
        .filter(Boolean)
        .join('  ');
      if (text) items.push({ text: text, link: a.href, group: 'table' });
    });
    return items;
  }

  function isBoundary(ch) {
    return ch === undefined || /[\s_\/\-.]/.test(ch);
  }

  function fuzzyScore(query, text) {
    if (!query) return 0;
    var q = query.toLowerCase();
    var t = text.toLowerCase();
    var score = 0;
    var qi = 0;
    var prev = -2;
    for (var ti = 0; ti < t.length && qi < q.length; ti++) {
      if (t[ti] === q[qi]) {
        score += ti === prev + 1 ? 3 : 1;
        if (isBoundary(t[ti - 1])) score += 2;
        prev = ti;
        qi++;
      }
    }
    return qi === q.length ? score : -1;
  }

  function rank(query, items) {
    if (!query) return items.slice();
    var scored = [];
    for (var i = 0; i < items.length; i++) {
      var s = fuzzyScore(query, items[i].text);
      if (s >= 0) scored.push({ item: items[i], score: s, index: i });
    }
    scored.sort(function (a, b) { return b.score - a.score || a.index - b.index; });
    return scored.map(function (e) { return e.item; });
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
      input {
        width: 100%;
        box-sizing: border-box;
        font: inherit;
        padding: 0.6em 0.75em;
        border: none;
        border-bottom: 1px solid var(--border-color);
        background: transparent;
        color: inherit;
        outline: none;
      }
      ul { list-style: none; margin: 0; padding: 0.25em; max-height: 50vh; overflow-y: auto; }
      li {
        padding: 0.35em 0.5em;
        border-radius: 0.25em;
        cursor: pointer;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      li.selected { background: var(--container-low-color); }
      li.empty { opacity: 0.6; cursor: default; }
      li.group {
        cursor: default;
        padding: 0.5em 0.5em 0.15em;
        opacity: 0.5;
        font-size: 0.85em;
        text-transform: uppercase;
        letter-spacing: 0.05em;
      }
      li.group:first-child { padding-top: 0.15em; }
    </style>
    <dialog part="modal">
      <input type="text" autocomplete="off" spellcheck="false" placeholder="Jump to…" />
      <ul></ul>
    </dialog>
  `;

  class QuickNav extends HTMLElement {
    connectedCallback() {
      if (!this.shadowRoot) this.attachShadow({ mode: 'open' });
      this.shadowRoot.innerHTML = template;
      this.modal = this.shadowRoot.querySelector('dialog');
      this.input = this.shadowRoot.querySelector('input');
      this.results = this.shadowRoot.querySelector('ul');
      this.items = [];
      this.matches = [];
      this.itemEls = [];
      this.selected = 0;

      this.input.addEventListener('input', function () {
        this.selected = 0;
        this.render();
      }.bind(this));

      this.modal.addEventListener('keydown', this.onKeydown.bind(this));
      this.modal.addEventListener('click', function (e) {
        if (e.target === this.modal) this.closeModal();
      }.bind(this));
      this.modal.addEventListener('close', function () {
        window.hashParams.remove('quick-nav');
      });

      if (!window.__quickNavBound) {
        window.__quickNavBound = true;
        document.addEventListener('keydown', function (e) {
          if (e.key !== '/' || e.metaKey || e.ctrlKey || e.altKey) return;
          var el = document.activeElement;
          var tag = el && el.tagName;
          if (tag === 'INPUT' || tag === 'TEXTAREA' || (el && el.isContentEditable)) return;
          var nav = document.querySelector('quick-nav');
          if (nav && !nav.isOpen()) {
            e.preventDefault();
            nav.openModal();
          }
        }, true);
      }

      if (window.hashParams.has('quick-nav')) {
        requestAnimationFrame(function () { this.openModal(); }.bind(this));
      }
    }

    isOpen() {
      return !!(this.modal && this.modal.open);
    }

    openModal() {
      this.items = scrapeItems();
      this.input.value = '';
      this.selected = 0;
      this.render();
      this.modal.showModal();
      this.input.focus();
      window.hashParams.set('quick-nav', '');
    }

    closeModal() {
      if (this.modal.open) this.modal.close();
    }

    onKeydown(e) {
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        this.move(1);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        this.move(-1);
      } else if (e.key === 'Enter') {
        e.preventDefault();
        this.choose(e.shiftKey);
      }
    }

    move(delta) {
      if (this.matches.length === 0) return;
      this.selected = (this.selected + delta + this.matches.length) % this.matches.length;
      this.highlight();
    }

    choose(keepOpen) {
      var match = this.matches[this.selected];
      if (!match) return;
      window.hashParams.remove('quick-nav');
      var url = new URL(match.link, window.location.href);
      url.hash = keepOpen ? 'quick-nav' : '';
      window.location.href = url.toString();
    }

    highlight() {
      for (var i = 0; i < this.itemEls.length; i++) {
        var on = i === this.selected;
        this.itemEls[i].classList.toggle('selected', on);
        if (on) this.itemEls[i].scrollIntoView({ block: 'nearest' });
      }
    }

    render() {
      var self = this;
      var ranked = rank(this.input.value.trim(), this.items);
      this.results.innerHTML = '';
      this.matches = [];
      this.itemEls = [];

      GROUPS.forEach(function (group) {
        var groupItems = ranked.filter(function (m) { return m.group === group.key; });
        if (groupItems.length === 0) return;
        var header = document.createElement('li');
        header.className = 'group';
        header.textContent = group.title;
        self.results.appendChild(header);
        groupItems.forEach(function (match) {
          var index = self.matches.length;
          self.matches.push(match);
          var li = document.createElement('li');
          li.textContent = match.text;
          if (index === self.selected) li.classList.add('selected');
          li.addEventListener('mousemove', function () {
            self.selected = index;
            self.highlight();
          });
          li.addEventListener('click', function () {
            self.selected = index;
            self.choose();
          });
          self.results.appendChild(li);
          self.itemEls.push(li);
        });
      });

      if (this.matches.length === 0) {
        var empty = document.createElement('li');
        empty.className = 'empty';
        empty.textContent = 'No matches';
        this.results.appendChild(empty);
      }
    }
  }

  if (!customElements.get('quick-nav')) customElements.define('quick-nav', QuickNav);
})();
