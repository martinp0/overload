// Living-room follow-along for Samsung Tizen (Chromium ~M85 on Tizen 6.5).
// Reuses the web app's generator, set logging and rest timer. No phone chrome.
// Keep this file, plus data.js / store.js / engine.js, free of APIs newer than M85.

import { TRACKS } from './data.js';
import {
  load, save, flush, state, getEx, fmtW, unit, increment, fromDisp,
} from './store.js';
import {
  ensureDraft, startWorkout, finishWorkout, lastSession, working, hasWeight,
} from './engine.js';

const root = document.getElementById('tv');
const KEY = {
  left: 37, up: 38, right: 39, down: 40, enter: 13,
  back: 10009, backAlt: 461, red: 403, green: 404, yellow: 405, blue: 406,
};

const ui = { screen: 'home', focus: 0, ex: 0, set: 0 };
let audio = null;
let homeItems = [];

function L(en, cz) {
  return /^cs/i.test(navigator.language || '') ? cz : en;
}

function esc(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function clock(ms) {
  const t = Math.max(0, Math.floor(ms / 1000));
  const m = Math.floor(t / 60);
  const s = t % 60;
  return m + ':' + (s < 10 ? '0' : '') + s;
}

function placeholders(entry) {
  const last = lastSession(entry.exId);
  const prev = last ? working(last.e.sets) : [];
  const out = [];
  let n = 0;
  for (let i = 0; i < entry.sets.length; i++) {
    const set = entry.sets[i];
    if (set.wu) {
      out.push({ w: null, r: null, s: null });
      continue;
    }
    const p = prev[n] || (prev.length ? prev[prev.length - 1] : null);
    n += 1;
    out.push({
      w: p && p.w != null ? p.w : null,
      r: p && p.r != null ? p.r : entry.min,
      s: p && p.s != null ? p.s : entry.min,
    });
  }
  return out;
}

function dose(set, ex, ph) {
  const u = unit();
  const w = set.w != null ? set.w : ph.w;
  const r = set.r != null ? set.r : ph.r;
  const s = set.s != null ? set.s : ph.s;
  const guessed = set.w == null && set.r == null && set.s == null;
  let text = '';
  if (ex.track === 't') text = (s != null ? s : '–') + ' sec';
  else if (ex.track === 'r') text = (r != null ? r : '–') + ' ' + L('reps', 'opak.');
  else if (ex.track === 'wt') text = (w != null ? fmtW(w) + ' ' + u : '–') + ' × ' + (s != null ? s : '–') + ' s';
  else if (ex.track === 'bw' && !(w > 0)) text = (r != null ? r : '–') + ' ' + L('reps', 'opak.');
  else text = (w != null ? fmtW(w) + ' ' + u : '–') + ' × ' + (r != null ? r : '–');
  return { text, guessed };
}

function unlockAudio() {
  if (!state.settings.sound || audio) return;
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (Ctx) audio = new Ctx();
  } catch (e) {
    audio = null;
  }
}

function beep() {
  if (!audio) return;
  if (audio.state === 'suspended') audio.resume();
  const t0 = audio.currentTime;
  for (let i = 0; i < 3; i++) {
    const osc = audio.createOscillator();
    const gain = audio.createGain();
    const d = i * 0.22;
    osc.frequency.value = i === 2 ? 1320 : 880;
    gain.gain.setValueAtTime(0.0001, t0 + d);
    gain.gain.exponentialRampToValueAtTime(0.25, t0 + d + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + d + 0.18);
    osc.connect(gain);
    gain.connect(audio.destination);
    osc.start(t0 + d);
    osc.stop(t0 + d + 0.2);
  }
}

function startRest(sec) {
  if (!state.active || !(sec > 0)) return;
  state.active.rest = { endsAt: Date.now() + sec * 1000, total: sec, alerted: false };
  save('active');
}

function clearRest() {
  if (!state.active || !state.active.rest) return;
  state.active.rest = null;
  save('active');
}

function firstOpenSet(entry) {
  for (let i = 0; i < entry.sets.length; i++) {
    if (!entry.sets[i].done) return i;
  }
  return 0;
}

function toggleSet() {
  const a = state.active;
  const entry = a && a.exercises[ui.ex];
  if (!entry) return;
  const set = entry.sets[ui.set];
  const ex = getEx(entry.exId, entry.name);
  if (!set) return;
  if (set.done) {
    set.done = false;
    save('active');
    return;
  }
  const ph = placeholders(entry)[ui.set];
  const fields = TRACKS[ex.track].fields;
  for (let i = 0; i < fields.length; i++) {
    const f = fields[i];
    if (set[f] != null) continue;
    if (ph[f] != null) set[f] = ph[f];
    else if (f === 'w' && ex.track === 'bw') set.w = 0;
    else {
      ui.needWeight = true;
      return;
    }
  }
  ui.needWeight = false;
  set.done = true;
  save('active');
  const workoutDone = a.exercises.every(function (e) {
    return e.sets.length > 0 && e.sets.every(function (s) { return s.done; });
  });
  if (state.settings.autoRest && !workoutDone) startRest(entry.rest);
  if (entry.sets[ui.set + 1]) ui.set += 1;
}

function nudge(dir) {
  const entry = state.active && state.active.exercises[ui.ex];
  if (!entry) return;
  const set = entry.sets[ui.set];
  const ex = getEx(entry.exId, entry.name);
  const ph = placeholders(entry)[ui.set];
  if (!hasWeight(ex)) {
    const f = ex.track === 't' ? 's' : 'r';
    const base = set[f] != null ? set[f] : (ph[f] != null ? ph[f] : entry.min || 0);
    set[f] = Math.max(0, base + dir);
  } else {
    const step = fromDisp(increment(ex)) || 1;
    const base = set.w != null ? set.w : (ph.w != null ? ph.w : 20);
    set.w = Math.max(0, Math.round((base + dir * step) * 100) / 100);
    if (set.r == null && ph.r != null && ex.track !== 'wt' && ex.track !== 't') set.r = ph.r;
    if (set.s == null && ph.s != null && (ex.track === 'wt' || ex.track === 't')) set.s = ph.s;
  }
  ui.needWeight = false;
  save('active');
}

function buildHome() {
  const draft = ensureDraft();
  const items = [{
    label: L('Start today’s workout', 'Začít dnešní trénink'),
    detail: draft.title + ' · ' + draft.items.length + ' ' + L('exercises', 'cviků'),
    run: function () {
      if (!draft.items.length) return;
      startWorkout(draft.items, { name: draft.title, split: draft.split || draft.resolved });
      ui.screen = 'workout';
      ui.ex = 0;
      ui.set = 0;
    },
  }];
  for (let i = 0; i < state.templates.length; i++) {
    const tpl = state.templates[i];
    items.push({
      label: tpl.name,
      detail: tpl.items.length + ' ' + L('exercises', 'cviků'),
      run: function () {
        startWorkout(tpl.items, { name: tpl.name });
        ui.screen = 'workout';
        ui.ex = 0;
        ui.set = 0;
      },
    });
  }
  homeItems = items;
  if (ui.focus >= items.length) ui.focus = 0;
}

function renderHome() {
  buildHome();
  const buttons = homeItems.map(function (item, i) {
    return '<button type="button" class="tv-row' + (i === ui.focus ? ' is-on' : '') + '" data-i="' + i + '">'
      + '<span class="tv-row-label">' + esc(item.label) + '</span>'
      + '<span class="tv-row-detail">' + esc(item.detail) + '</span>'
      + '</button>';
  }).join('');
  const resume = state.active
    ? '<button type="button" class="tv-resume' + (ui.focus === -1 ? ' is-on' : '') + '" data-resume="1">'
      + esc(L('Resume', 'Pokračovat')) + ' · ' + esc(state.active.name) + '</button>'
    : '';
  root.innerHTML = '<div class="tv-app">'
    + '<header class="tv-top"><div class="brand">OVERLOAD</div>'
    + '<p class="tv-tag">' + esc(L('Follow along from the couch or the bench.', 'Cviky a pauza na velkou obrazovku.')) + '</p></header>'
    + '<div class="tv-home">' + resume + buttons + '</div>'
    + '<footer class="tv-hints"><span>' + esc(L('▲▼ choose', '▲▼ výběr')) + '</span><span>OK</span></footer>'
    + '</div>';
}

function renderWorkout() {
  const a = state.active;
  if (!a) {
    ui.screen = 'home';
    renderHome();
    return;
  }
  if (ui.ex >= a.exercises.length) ui.ex = 0;
  const entry = a.exercises[ui.ex];
  const ex = getEx(entry.exId, entry.name);
  if (ui.set >= entry.sets.length) ui.set = 0;
  const phs = placeholders(entry);
  const set = entry.sets[ui.set];
  const shown = dose(set, ex, phs[ui.set] || { w: null, r: null, s: null });
  const resting = !!a.rest;
  const list = a.exercises.map(function (e, i) {
    const name = getEx(e.exId, e.name).name;
    const done = e.sets.filter(function (s) { return s.done; }).length;
    return '<li class="' + (i === ui.ex ? 'is-on' : '') + (done === e.sets.length ? ' done' : '') + '">'
      + '<span class="tv-ex-name">' + esc(name) + '</span>'
      + '<span class="tv-ex-meta">' + done + '/' + e.sets.length + '</span></li>';
  }).join('');
  const setDots = entry.sets.map(function (s, i) {
    return '<span class="pip' + (i === ui.set ? ' is-on' : '') + (s.done ? ' done' : '') + '"></span>';
  }).join('');
  const warn = ui.needWeight
    ? '<p class="tv-warn">' + esc(L('Set a weight with the yellow and blue keys.', 'Váhu změníš žlutým a modrým tlačítkem.')) + '</p>'
    : '';
  root.innerHTML = '<div class="tv-app' + (resting ? ' resting' : '') + '">'
    + '<header class="tv-top"><div class="brand">OVERLOAD</div>'
    + '<h1 class="tv-session">' + esc(a.name) + '</h1>'
    + '<p class="tv-elapsed" data-tv-elapsed>' + clock(Date.now() - a.startedAt) + '</p></header>'
    + '<div class="tv-main">'
    + '<ol class="tv-ex">' + list + '</ol>'
    + '<section class="tv-stage">'
    + '<p class="eyebrow">' + esc(L('Set', 'Série')) + ' ' + (ui.set + 1) + ' / ' + entry.sets.length + '</p>'
    + '<h2 class="lift">' + esc(ex.name) + '</h2>'
    + '<p class="dose' + (shown.guessed ? ' guessed' : '') + '">' + esc(shown.text) + '</p>'
    + '<div class="pips">' + setDots + '</div>'
    + warn
    + '<p class="tv-sub">' + esc(shown.guessed
      ? L('OK logs the weight from last time.', 'OK zapíše váhu z minula.')
      : L('OK logs this set and starts the rest.', 'OK zapíše sérii a spustí pauzu.')) + '</p>'
    + '</section>'
    + '<aside class="tv-side">'
    + (resting
      ? '<p class="eyebrow">' + esc(L('Rest', 'Pauza')) + '</p><p class="rest-num" data-tv-rest>0:00</p><div class="bar"><i data-tv-restbar></i></div>'
      : '<p class="eyebrow">' + esc(L('Next rest', 'Další pauza')) + '</p><p class="rest-next">' + clock((entry.rest || 0) * 1000) + '</p>')
    + '</aside></div>'
    + '<footer class="tv-hints">'
    + '<span>▲▼ ' + esc(L('exercise', 'cvik')) + '</span>'
    + '<span>◀▶ ' + esc(L('set', 'série')) + '</span>'
    + '<span>OK ' + esc(L('log', 'zapsat')) + '</span>'
    + '<span class="key y">' + esc(L('yellow −', 'žlutá −')) + '</span>'
    + '<span class="key b">' + esc(L('blue +', 'modrá +')) + '</span>'
    + '<span class="key r">' + esc(L('red skip rest', 'červená přeskočí pauzu')) + '</span>'
    + '<span class="key g">' + esc(L('green finish', 'zelená konec')) + '</span>'
    + '</footer></div>';
  tick();
}

function renderConfirm() {
  const choices = [
    L('Save workout', 'Uložit trénink'),
    L('Keep going', 'Ještě pokračovat'),
    L('End without saving', 'Skončit bez uložení'),
  ];
  const buttons = choices.map(function (label, i) {
    return '<button type="button" class="tv-choice' + (i === ui.focus ? ' is-on' : '') + '">' + esc(label) + '</button>';
  }).join('');
  root.innerHTML = '<div class="tv-app"><header class="tv-top"><div class="brand">OVERLOAD</div></header>'
    + '<div class="tv-confirm"><h2>' + esc(L('Finish this workout?', 'Ukončit trénink?')) + '</h2>' + buttons + '</div></div>';
}

function render() {
  if (ui.screen === 'workout' && state.active) renderWorkout();
  else if (ui.screen === 'confirm') renderConfirm();
  else renderHome();
  const on = root.querySelector('.is-on');
  if (on && on.scrollIntoView) on.scrollIntoView({ block: 'nearest' });
}

function activateHome() {
  if (ui.focus === -1 && state.active) {
    ui.screen = 'workout';
    ui.ex = 0;
    ui.set = firstOpenSet(state.active.exercises[0]);
    return;
  }
  const item = homeItems[ui.focus];
  if (item) item.run();
}

function confirmChoice() {
  if (ui.focus === 0) {
    finishWorkout();
    ui.screen = 'home';
    ui.focus = 0;
  } else if (ui.focus === 2) {
    state.active = null;
    save('active');
    ui.screen = 'home';
    ui.focus = 0;
  } else {
    ui.screen = 'workout';
  }
}

function onKey(e) {
  const code = e.keyCode || e.which;
  const back = code === KEY.back || code === KEY.backAlt || e.key === 'Escape' || e.key === 'BrowserBack';
  const up = code === KEY.up || e.key === 'ArrowUp';
  const down = code === KEY.down || e.key === 'ArrowDown';
  const left = code === KEY.left || e.key === 'ArrowLeft';
  const right = code === KEY.right || e.key === 'ArrowRight';
  const enter = code === KEY.enter || e.key === 'Enter' || e.key === ' ';
  if (up || down || left || right || enter || back) e.preventDefault();
  unlockAudio();

  if (ui.screen === 'home') {
    const extra = state.active ? 1 : 0;
    const n = homeItems.length + extra;
    if (up || down) {
      const cur = ui.focus === -1 ? 0 : ui.focus + extra;
      const next = up ? (cur + n - 1) % n : (cur + 1) % n;
      ui.focus = extra && next === 0 ? -1 : next - extra;
      render();
    } else if (enter) {
      activateHome();
      render();
    }
    return;
  }

  if (ui.screen === 'confirm') {
    if (up || down) {
      ui.focus = (ui.focus + (down ? 1 : 2)) % 3;
      render();
    } else if (enter) {
      confirmChoice();
      render();
    } else if (back) {
      ui.screen = 'workout';
      render();
    }
    return;
  }

  const a = state.active;
  if (!a) return;
  if (up || down) {
    ui.ex = (ui.ex + (down ? 1 : a.exercises.length - 1)) % a.exercises.length;
    ui.set = firstOpenSet(a.exercises[ui.ex]);
    ui.needWeight = false;
    render();
  } else if (left || right) {
    const sets = a.exercises[ui.ex].sets;
    ui.set = (ui.set + (right ? 1 : sets.length - 1)) % sets.length;
    ui.needWeight = false;
    render();
  } else if (enter) {
    toggleSet();
    render();
  } else if (code === KEY.yellow || e.key === '-' || e.key === '_') {
    nudge(-1);
    render();
  } else if (code === KEY.blue || e.key === '+' || e.key === '=') {
    nudge(1);
    render();
  } else if (code === KEY.red || e.key === 'Backspace') {
    if (a.rest) clearRest();
    render();
  } else if (code === KEY.green || e.key === 'f') {
    ui.screen = 'confirm';
    ui.focus = 0;
    render();
  } else if (back) {
    ui.screen = 'home';
    ui.focus = state.active ? -1 : 0;
    render();
  }
}

function tick() {
  const a = state.active;
  const now = Date.now();
  const elapsed = document.querySelector('[data-tv-elapsed]');
  if (elapsed && a) elapsed.textContent = clock(now - a.startedAt);
  const r = a && a.rest;
  if (!r) return;
  const left = Math.ceil((r.endsAt - now) / 1000);
  if (left <= 0 && !r.alerted) {
    r.alerted = true;
    save('active');
    beep();
  }
  if (left <= -3) {
    clearRest();
    if (ui.screen === 'workout') render();
    return;
  }
  const time = document.querySelector('[data-tv-rest]');
  const bar = document.querySelector('[data-tv-restbar]');
  if (time) time.textContent = left > 0 ? clock(left * 1000) : L('Go', 'Teď');
  if (bar) bar.style.width = Math.max(0, Math.min(100, (left / r.total) * 100)) + '%';
}

load();
if (state.active) {
  ui.screen = 'workout';
  ui.set = firstOpenSet(state.active.exercises[0] || { sets: [] });
}
render();
document.addEventListener('keydown', onKey);
setInterval(tick, 250);
window.addEventListener('pagehide', flush);
