const MODIFIERS = ['shift', 'alt', 'ctrl', 'meta'];

function parseCombo(raw) {
  const parts = Array.isArray(raw) ? raw : raw.toLowerCase().split('+');
  const modifiers = { shift: false, alt: false, ctrl: false, meta: false };
  const keys = [];

  for (const part of parts) {
    if (MODIFIERS.includes(part)) {
      modifiers[part] = true;
    } else {
      keys.push(part);
    }
  }

  return { modifiers, keys };
}

function matchesCombo(event, spec) {
  const modifiersMatch =
    event.shiftKey === spec.modifiers.shift &&
    event.altKey   === spec.modifiers.alt   &&
    event.ctrlKey  === spec.modifiers.ctrl  &&
    event.metaKey  === spec.modifiers.meta;

  if (!modifiersMatch) return false;
  if (spec.keys.length === 0) return true;

  const pressed = event.key.toLowerCase();
  return spec.keys.includes(pressed);
}

class KeyComboBuilder {
  constructor(combos) {
    this.specs = combos.map(parseCombo);
  }

  do(callback) {
    return (event) => {
      if (this.specs.some(spec => matchesCombo(event, spec))) {
        callback(event);
      }
    };
  }
}

export const KeyCombo = {
  on(...combos) {
    return new KeyComboBuilder(combos);
  },
};
