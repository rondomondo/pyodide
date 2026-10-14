import { KeyCombo } from './KeyCombo.js';

const THEMES = ['dark', 'light'];

function readStored(key) {
  try {
    return localStorage.getItem(key);
  } catch (e) {
    return null;
  }
}

function writeStored(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch (e) {
    // storage can be blocked; the theme simply will not persist
  }
}

function initTheme(storageKey) {
  const dots = document.querySelectorAll('.theme-dot');

  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    dots.forEach((dot) => dot.classList.toggle('active', dot.dataset.t === theme));
    writeStored(storageKey, theme);
  }

  dots.forEach((dot) => dot.addEventListener('click', () => applyTheme(dot.dataset.t)));

  const saved = readStored(storageKey);
  const prefersLight = window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches;
  applyTheme(THEMES.includes(saved) ? saved : prefersLight ? 'light' : 'dark');
}

function isEditable(target) {
  return target instanceof HTMLElement && (target.isContentEditable || /^(TEXTAREA|INPUT|SELECT)$/.test(target.tagName));
}

/**
 * Wire up the theme picker, plain/technical view toggle, reset key and mobile menu.
 *
 * @param {{themeKey: string, onReset: () => void}} options
 */
export function initShell({ themeKey, onReset }) {
  initTheme(themeKey);

  let techMode = false;

  function setView(tech) {
    techMode = tech;
    document.querySelectorAll('.txt-simple').forEach((el) => (el.hidden = tech));
    document.querySelectorAll('.txt-tech').forEach((el) => (el.hidden = !tech));
  }

  function resetAll() {
    setView(false);
    onReset();
  }

  // Esc inside a text field only leaves the field, so pasted work is not wiped by accident.
  document.addEventListener(
    'keydown',
    KeyCombo.on('escape').do((event) => {
      if (isEditable(event.target)) {
        event.target.blur();
        return;
      }
      resetAll();
    }),
  );

  document.addEventListener(
    'keydown',
    KeyCombo.on('ctrl+shift+s').do((event) => {
      event.preventDefault();
      setView(!techMode);
    }),
  );

  const fab = document.getElementById('fab');
  const fabMenu = document.getElementById('fab-menu');

  fab.addEventListener('click', (event) => {
    event.stopPropagation();
    fabMenu.classList.toggle('open');
  });
  document.getElementById('fab-toggle-view').addEventListener('click', () => {
    fabMenu.classList.remove('open');
    setView(!techMode);
  });
  document.getElementById('fab-reset').addEventListener('click', () => {
    fabMenu.classList.remove('open');
    resetAll();
  });
  document.addEventListener('click', () => fabMenu.classList.remove('open'));

  setView(false);
}

/**
 * Show a boot or runtime status line.
 *
 * @param {string} message
 * @param {'loading' | 'ready' | 'failed'} state
 */
export function setStatus(message, state) {
  const statusEl = document.getElementById('status');
  document.getElementById('status-text').textContent = message;
  statusEl.classList.toggle('ready', state === 'ready');
  statusEl.classList.toggle('loading', state === 'loading');
  statusEl.classList.toggle('failed', state === 'failed');
}

/**
 * Fetch a Python source file and import it as a module inside Pyodide.
 *
 * @param {object} pyodide
 * @param {string} name module name without extension
 * @returns {Promise<object>} the imported module proxy
 */
export async function loadPyModule(pyodide, name) {
  const response = await fetch(`py/${name}.py`);
  if (!response.ok) {
    throw new Error(`could not load py/${name}.py (${response.status})`);
  }
  pyodide.FS.writeFile(`/home/pyodide/${name}.py`, await response.text());
  return pyodide.pyimport(name);
}

/**
 * Format a byte count for display.
 *
 * @param {number} bytes
 * @returns {string}
 */
export function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}
