(function () {
  if (window.hashParams) return;

  function read() {
    return new URLSearchParams(window.location.hash.slice(1));
  }

  function serialize(p) {
    var parts = [];
    p.forEach(function (value, key) {
      parts.push(value === '' ? encodeURIComponent(key) : encodeURIComponent(key) + '=' + encodeURIComponent(value));
    });
    return parts.join('&');
  }

  function write(p) {
    var s = serialize(p);
    var base = window.location.pathname + window.location.search;
    history.replaceState(null, '', s ? base + '#' + s : base);
  }

  window.hashParams = {
    get: function (key) {
      return read().get(key);
    },
    has: function (key) {
      return read().has(key);
    },
    set: function (key, value) {
      var p = read();
      if (value === null || value === undefined) p.delete(key);
      else p.set(key, value);
      write(p);
    },
    remove: function (key) {
      this.set(key, null);
    },
  };
})();
