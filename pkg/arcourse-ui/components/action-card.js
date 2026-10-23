function isDirty(controls) {
  return Array.prototype.some.call(controls, function (control) {
    if (control.options) {
      const defaultIndex = Array.prototype.findIndex.call(control.options, function (option) {
        return option.defaultSelected;
      });
      return control.selectedIndex !== Math.max(defaultIndex, 0);
    }
    return control.value !== control.defaultValue;
  });
}

if (typeof HTMLElement !== 'undefined') {
  class ActionCard extends HTMLElement {
    connectedCallback() {
      this.update = this.update.bind(this);
      this.addEventListener('input', this.update);
      this.addEventListener('change', this.update);
      window.addEventListener('pageshow', this.update);
      this.update();
    }

    disconnectedCallback() {
      window.removeEventListener('pageshow', this.update);
    }

    update() {
      const apply = this.querySelector('form.apply button');
      if (!apply) return;
      apply.disabled = isDirty(this.querySelectorAll('form.params input, form.params select'));
    }
  }

  if (!customElements.get('action-card')) customElements.define('action-card', ActionCard);
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { isDirty };
}
