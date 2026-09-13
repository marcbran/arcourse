(function () {
  if (window.__tableSortBound) return;
  window.__tableSortBound = true;

  var observer = null;

  function headers(table) {
    return Array.prototype.slice.call(table.querySelectorAll('thead th'));
  }

  function cellText(row, i) {
    var td = row.children[i];
    return td ? td.textContent.trim() : '';
  }

  function compare(a, b) {
    var na = Number(a);
    var nb = Number(b);
    if (a !== '' && b !== '' && !isNaN(na) && !isNaN(nb)) return na - nb;
    return a.localeCompare(b);
  }

  function firstCol(table) {
    var th = table.querySelector('thead th');
    return th ? th.dataset.col : null;
  }

  function apply(table) {
    var ths = headers(table);
    ths.forEach(function (th) { th.classList.remove('sort-asc', 'sort-desc'); });
    if (ths.length === 0) return;
    var key = window.hashParams.get('sort');
    var desc = window.hashParams.get('dir') === 'desc';
    var i = 0;
    if (key) {
      i = -1;
      ths.forEach(function (th, idx) { if (th.dataset.col === key) i = idx; });
      if (i < 0) { i = 0; desc = false; }
    } else {
      desc = false;
    }
    ths[i].classList.add(desc ? 'sort-desc' : 'sort-asc');
    var tbody = table.querySelector('tbody');
    if (!tbody || tbody.querySelector('td.empty')) return;
    var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
    rows.sort(function (a, b) {
      var r = compare(cellText(a, i), cellText(b, i));
      return desc ? -r : r;
    });
    rows.forEach(function (r) { tbody.appendChild(r); });
  }

  function applyAll() {
    if (observer) observer.disconnect();
    document.querySelectorAll('table.table').forEach(apply);
    if (observer) {
      var target = document.getElementById('node') || document.body;
      if (target) observer.observe(target, { childList: true, subtree: true });
    }
  }

  document.addEventListener('click', function (e) {
    var th = e.target.closest ? e.target.closest('th') : null;
    if (!th || !th.dataset.col) return;
    var table = th.closest('table.table');
    if (!table) return;
    var key = th.dataset.col;
    var first = firstCol(table);
    var curKey = window.hashParams.get('sort') || first;
    var curDesc = window.hashParams.get('dir') === 'desc';
    var nextKey;
    var nextDesc;
    if (curKey !== key) {
      nextKey = key;
      nextDesc = false;
    } else if (!curDesc) {
      nextKey = key;
      nextDesc = true;
    } else {
      nextKey = first;
      nextDesc = false;
    }
    if (nextKey === first && !nextDesc) {
      window.hashParams.remove('sort');
      window.hashParams.remove('dir');
    } else {
      window.hashParams.set('sort', nextKey);
      if (nextDesc) window.hashParams.set('dir', 'desc');
      else window.hashParams.remove('dir');
    }
    applyAll();
  });

  function init() {
    observer = new MutationObserver(applyAll);
    applyAll();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
