import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import {
  classifyLayout, heightSizeClass, isCoverViewport, postureFromSegments, windowSizeClass,
} from './fold-metrics.js';

test('window size classes match Material breakpoints', () => {
  assert.equal(windowSizeClass(0), 'compact');
  assert.equal(windowSizeClass(599), 'compact');
  assert.equal(windowSizeClass(600), 'medium');
  assert.equal(windowSizeClass(839), 'medium');
  assert.equal(windowSizeClass(840), 'expanded');
  assert.equal(windowSizeClass(1199), 'expanded');
  assert.equal(windowSizeClass(1200), 'large');
  assert.equal(windowSizeClass(1599), 'large');
  assert.equal(windowSizeClass(1600), 'xlarge');
  assert.equal(heightSizeClass(479), 'compact');
  assert.equal(heightSizeClass(480), 'medium');
  assert.equal(heightSizeClass(899), 'medium');
  assert.equal(heightSizeClass(900), 'expanded');
});

test('cover heuristic matches Flip covers and ignores phones and pop-ups', () => {
  assert.equal(isCoverViewport(390, 844), false);
  assert.equal(isCoverViewport(360, 800), false);
  assert.equal(isCoverViewport(412, 915), false);
  assert.equal(isCoverViewport(400, 640), false);
  assert.equal(isCoverViewport(884, 1104), false);
  assert.equal(isCoverViewport(1280, 800), false);
  assert.equal(isCoverViewport(360, 380), true);
  assert.equal(isCoverViewport(374, 360), true);
  assert.equal(isCoverViewport(260, 512), true);
  assert.equal(isCoverViewport(320, 640), true);
});

test('viewport segments become flex or book hinges', () => {
  const flex = postureFromSegments([
    { x: 0, y: 0, width: 400, height: 380 },
    { x: 0, y: 400, width: 400, height: 380 },
  ]);
  assert.equal(flex.posture, 'flex');
  assert.equal(flex.hinge.top, 380);
  assert.equal(flex.hinge.size, 20);

  const book = postureFromSegments([
    { x: 0, y: 0, width: 400, height: 800 },
    { x: 420, y: 0, width: 400, height: 800 },
  ]);
  assert.equal(book.posture, 'book');
  assert.equal(book.hinge.left, 400);
  assert.equal(book.hinge.size, 20);
  assert.equal(postureFromSegments([{ x: 0, y: 0, width: 400, height: 800 }]), null);
});

test('classifyLayout prefers the Android bridge over the preview query', () => {
  const phone = classifyLayout({ width: 390, height: 844 });
  assert.deepEqual(
    { posture: phone.posture, cover: phone.cover, windowClass: phone.windowClass },
    { posture: 'flat', cover: false, windowClass: 'compact' },
  );

  const cover = classifyLayout({ width: 360, height: 380 });
  assert.equal(cover.cover, true);
  assert.equal(cover.posture, 'flat');

  const preview = classifyLayout({ width: 412, height: 900, preview: 'flex' });
  assert.equal(preview.posture, 'flex');
  assert.equal(preview.cover, false);
  assert.ok(preview.hinge.top > 200);

  const native = classifyLayout({
    width: 360,
    height: 380,
    preview: 'flex',
    native: { posture: 'flat', multiWindow: true },
  });
  assert.equal(native.posture, 'flat');
  assert.equal(native.cover, true);
  assert.equal(native.multiWindow, true);

  const half = classifyLayout({
    width: 412,
    height: 900,
    native: { posture: 'flex', hinge: { orientation: 'horizontal', top: 430, left: 0, size: 32 } },
  });
  assert.equal(half.posture, 'flex');
  assert.equal(half.cover, false);
  assert.equal(half.hinge.size, 32);
});

test('TV bundle stays on the Tizen 6.5 JavaScript subset', () => {
  for (const file of ['data.js', 'store.js', 'engine.js', 'tv-app.js']) {
    const src = readFileSync(new URL(`./${file}`, import.meta.url), 'utf8');
    assert.doesNotMatch(src, /\.at\(/, `${file} uses Array.prototype.at`);
    assert.doesNotMatch(src, /\.replaceAll\(/, `${file} uses replaceAll`);
    assert.doesNotMatch(src, /\.findLast\(/, `${file} uses findLast`);
    assert.doesNotMatch(src, /structuredClone\(/, `${file} uses structuredClone`);
  }
  const tv = readFileSync(new URL('./tv-app.js', import.meta.url), 'utf8');
  assert.doesNotMatch(tv, /from '\.\/ui\.js'/);
  assert.match(tv, /from '\.\/engine\.js'/);
  assert.match(tv, /from '\.\/store\.js'/);
});
