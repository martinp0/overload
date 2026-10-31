// Foldable layout for Galaxy Z Flip and Z Fold.
// Sets attributes and CSS variables only. It must not re-render the view: a fold,
// unfold, or resize has to keep the workout, the focused input, and the route.

import { classifyLayout } from './fold-metrics.js';
import { state, getEx } from './store.js';

const ROUTE_KEY = 'overload.route';
let nativeLayout = null;

const cs = () => /^cs/i.test(navigator.language || '');
const t = (en, cz) => (cs() ? cz : en);

function previewMode() {
  try {
    return new URLSearchParams(location.search).get('fold');
  } catch {
    return null;
  }
}

function readSegments() {
  const raw = window.visualViewport && window.visualViewport.segments;
  if (!raw || !raw.length) return null;
  return [...raw].map((r) => ({ x: r.x, y: r.y, width: r.width, height: r.height }));
}

export function rememberRoute() {
  if (!wantsContinuity()) return;
  try {
    const hash = location.hash || '#/';
    if (hash.startsWith('#/')) localStorage.setItem(ROUTE_KEY, hash);
  } catch { /* private mode */ }
}

function wantsContinuity() {
  if (document.documentElement.dataset.native === 'android') return true;
  if (window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform()) return true;
  try {
    return matchMedia('(display-mode: standalone)').matches;
  } catch {
    return false;
  }
}

export function restoreRoute() {
  if (!wantsContinuity() || location.hash) return;
  try {
    const saved = localStorage.getItem(ROUTE_KEY);
    if (typeof saved === 'string' && saved.startsWith('#/')) location.replace(saved);
  } catch { /* ignore */ }
}

function applyVariables(hinge) {
  const root = document.documentElement;
  if (!hinge) {
    root.style.removeProperty('--fold-top');
    root.style.removeProperty('--fold-hinge');
    root.style.removeProperty('--fold-left');
    root.style.removeProperty('--fold-right');
    return;
  }
  const w = document.documentElement.clientWidth;
  const h = document.documentElement.clientHeight;
  if (hinge.orientation === 'horizontal') {
    const size = Math.max(0, hinge.size || 0);
    const top = Math.max(0, Math.min(hinge.top, Math.max(0, h - size)));
    root.style.setProperty('--fold-top', `${top}px`);
    root.style.setProperty('--fold-hinge', `${size}px`);
    root.style.removeProperty('--fold-left');
    root.style.removeProperty('--fold-right');
  } else {
    const size = Math.max(0, hinge.size || 0);
    const left = Math.max(0, Math.min(hinge.left, Math.max(0, w - size)));
    root.style.setProperty('--fold-left', `${left}px`);
    root.style.setProperty('--fold-hinge', `${size}px`);
    root.style.setProperty('--fold-right', `${Math.max(0, w - left - size)}px`);
    root.style.removeProperty('--fold-top');
  }
}

function mirrorHandlers() {
  const view = document.getElementById('view');
  const stage = document.getElementById('fold-stage');
  if (!view || !stage) return;
  stage.onclick = view.onclick;
  stage.oninput = view.oninput;
  stage.onchange = view.onchange;
  stage.onkeydown = view.onkeydown;
  stage.onfocusin = view.onfocusin;
}

// Move the controls pane across the hinge without recreating it, so a half-typed
// weight survives the fold. Clicks are delegated from #view; the stage mirrors them.
export function layoutFoldRegions() {
  const stage = document.getElementById('fold-stage');
  const view = document.getElementById('view');
  if (!stage || !view) return;
  const posture = document.documentElement.dataset.posture;
  const split = posture === 'flex' || posture === 'book';
  const controls = document.querySelector('.fold-controls');
  if (split && controls) {
    if (controls.parentElement !== stage) stage.appendChild(controls);
    stage.hidden = false;
  } else if (controls && stage.contains(controls)) {
    const home = view.querySelector('.fold-split') || view;
    home.appendChild(controls);
    stage.hidden = true;
  } else {
    stage.hidden = true;
  }
  mirrorHandlers();
}

let coverSig = '';

function coverModel() {
  const a = state.active;
  if (!a) {
    return {
      kicker: 'Overload',
      title: t('No workout yet', 'Žádný trénink'),
      sub: t('Open the phone to start.', 'Otevři telefon a začni.'),
      rest: false,
      elapsed: false,
    };
  }
  const uid = (location.hash.match(/#\/workout\/([^/?]+)/) || [])[1];
  const entry = a.exercises.find((e) => e.uid === uid)
    || a.exercises.find((e) => e.sets.some((s) => !s.done))
    || a.exercises[0];
  const ex = entry ? getEx(entry.exId, entry.name) : null;
  const sets = entry ? entry.sets.filter((s) => !s.wu) : [];
  const done = sets.filter((s) => s.done).length;
  return {
    kicker: a.name,
    title: ex ? ex.name : a.name,
    sub: entry ? t(`${done} of ${sets.length} sets`, `${done} z ${sets.length} sérií`) : '',
    rest: !!a.rest,
    elapsed: true,
  };
}

export function renderCover() {
  const el = document.getElementById('cover-glance');
  if (!el) return;
  const on = document.documentElement.dataset.cover === '1';
  document.body.classList.toggle('cover-mode', on);
  if (!on) {
    el.hidden = true;
    coverSig = '';
    return;
  }
  const m = coverModel();
  const sig = `${m.kicker}|${m.title}|${m.sub}|${m.rest}`;
  el.hidden = false;
  if (sig === coverSig && el.childElementCount) return;
  coverSig = sig;
  const time = m.rest
    ? '<p class="cover-time" data-rest-time>0:00</p><div class="rest-bar cover-bar"><i data-rest-bar></i></div>'
    : `<p class="cover-time" ${m.elapsed ? 'data-elapsed' : ''}>${m.elapsed ? '0:00' : ''}</p>`;
  const actions = m.rest
    ? `<div class="cover-actions">
        <button class="btn" data-rest-act="-15" type="button">−15</button>
        <button class="btn" data-rest-act="15" type="button">+15</button>
        <button class="btn primary" data-rest-act="skip" type="button">${t('Skip', 'Přeskočit')}</button>
      </div>`
    : `<p class="cover-note">${t('Open the phone to log sets.', 'Otevři telefon a zapisuj série.')}</p>`;
  el.innerHTML = `
    <p class="cover-kicker">${escapeHtml(m.kicker)}</p>
    <h1 class="cover-title">${escapeHtml(m.title)}</h1>
    <p class="cover-sub">${escapeHtml(m.sub)}</p>
    <div class="cover-clock ${m.rest ? 'rest' : ''}" data-rest>
      <p class="cover-label">${m.rest ? t('Rest', 'Pauza') : t('Workout', 'Trénink')}</p>
      ${time}
      ${actions}
    </div>`;
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function measure() {
  const root = document.documentElement;
  const width = root.clientWidth || window.innerWidth;
  const height = root.clientHeight || window.innerHeight;
  const layout = classifyLayout({
    width,
    height,
    preview: previewMode(),
    native: nativeLayout,
    segments: readSegments(),
    devicePosture: navigator.devicePosture && navigator.devicePosture.type,
  });
  root.dataset.window = layout.windowClass;
  root.dataset.height = layout.heightClass;
  root.dataset.posture = layout.posture;
  if (layout.cover) root.dataset.cover = '1';
  else delete root.dataset.cover;
  if (layout.multiWindow) root.dataset.multiwindow = '1';
  else delete root.dataset.multiwindow;
  applyVariables(layout.posture === 'flat' ? null : layout.hinge);
  layoutFoldRegions();
  renderCover();
}

function pullNative() {
  let raw = null;
  try {
    raw = window.OverloadFold && window.OverloadFold.layout && window.OverloadFold.layout();
  } catch { /* bridge not ready */ }
  if (!raw) return;
  try {
    applyNative(JSON.parse(raw));
  } catch { /* ignore malformed payload */ }
}

function applyNative(info) {
  if (!info || typeof info !== 'object') return;
  nativeLayout = info;
  document.documentElement.dataset.native = 'android';
  measure();
}

let frame = 0;
function onResize() {
  if (frame) cancelAnimationFrame(frame);
  frame = requestAnimationFrame(() => {
    frame = 0;
    measure();
  });
}

export function initFold() {
  window.__overloadFold = applyNative;
  window.__overloadCover = renderCover;
  if (window.Capacitor && window.Capacitor.getPlatform && window.Capacitor.getPlatform() === 'android') {
    document.documentElement.dataset.native = 'android';
  }
  if (window.OverloadFold) document.documentElement.dataset.native = 'android';
  restoreRoute();
  measure();
  window.addEventListener('resize', onResize);
  if (window.visualViewport) window.visualViewport.addEventListener('resize', onResize);
  const posture = navigator.devicePosture;
  if (posture && posture.addEventListener) posture.addEventListener('change', measure);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      pullNative();
      measure();
    }
  });
  pullNative();
  setTimeout(pullNative, 400);
}

export function clearFoldStage() {
  const stage = document.getElementById('fold-stage');
  if (!stage) return;
  stage.replaceChildren();
  stage.onclick = null;
  stage.oninput = null;
  stage.onchange = null;
  stage.onkeydown = null;
  stage.onfocusin = null;
  stage.hidden = true;
}
