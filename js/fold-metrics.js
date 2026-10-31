// Window size classes and fold posture, shared by the page and the unit tests.
// Width classes follow Material window size classes:
// compact < 600, medium < 840, expanded < 1200, large < 1600, extra-large ≥ 1600.
// Height: compact < 480, medium < 900, expanded ≥ 900.

export function windowSizeClass(width) {
  if (width < 600) return 'compact';
  if (width < 840) return 'medium';
  if (width < 1200) return 'expanded';
  if (width < 1600) return 'large';
  return 'xlarge';
}

export function heightSizeClass(height) {
  if (height < 480) return 'compact';
  if (height < 900) return 'medium';
  return 'expanded';
}

// Flip cover displays are either a narrow strip (Flip 3/4, about 260×512 CSS px)
// or a small nearly-square panel (Flip 5/6, about 360×380 CSS px). A normal phone
// and a Samsung pop-up window are taller than that, so they stay on the full UI.
export function isCoverViewport(width, height) {
  if (!(width >= 80 && height >= 80)) return false;
  const min = Math.min(width, height);
  const max = Math.max(width, height);
  const area = width * height;
  const ratio = max / min;
  const squareCover = ratio <= 1.35 && max <= 520 && area <= 280000;
  const stripCover = ratio >= 1.55 && min <= 340 && max <= 700 && area <= 220000;
  return squareCover || stripCover;
}

function rectBottom(r) {
  return r.y + r.height;
}

function rectRight(r) {
  return r.x + r.width;
}

// Viewport Segments are DOMRects in CSS pixels. Two stacked rects are Flex / tabletop
// (horizontal hinge). Two side-by-side rects are book posture (vertical hinge).
export function postureFromSegments(segments) {
  if (!segments || segments.length < 2) return null;
  const a = segments[0];
  const b = segments[1];
  const stacked = a.x < rectRight(b) && b.x < rectRight(a)
    && (rectBottom(a) <= b.y + 1 || rectBottom(b) <= a.y + 1);
  const sideBySide = a.y < rectBottom(b) && b.y < rectBottom(a)
    && (rectRight(a) <= b.x + 1 || rectRight(b) <= a.x + 1);
  if (stacked && !sideBySide) {
    const top = a.y <= b.y ? a : b;
    const bot = a.y <= b.y ? b : a;
    return {
      posture: 'flex',
      hinge: {
        orientation: 'horizontal',
        top: rectBottom(top),
        left: 0,
        size: Math.max(0, bot.y - rectBottom(top)),
      },
    };
  }
  if (sideBySide && !stacked) {
    const left = a.x <= b.x ? a : b;
    const right = a.x <= b.x ? b : a;
    return {
      posture: 'book',
      hinge: {
        orientation: 'vertical',
        top: 0,
        left: rectRight(left),
        size: Math.max(0, right.x - rectRight(left)),
      },
    };
  }
  return null;
}

// Device Posture API reports "folded" for a half-open hinge and does not always
// include segment rects. Split the window in half along its shorter axis.
export function postureFromDevicePosture(type, width, height) {
  if (type !== 'folded') return null;
  const size = 24;
  if (width >= height) {
    return {
      posture: 'book',
      hinge: { orientation: 'vertical', top: 0, left: Math.max(0, Math.round((width - size) / 2)), size },
    };
  }
  return {
    posture: 'flex',
    hinge: { orientation: 'horizontal', top: Math.max(0, Math.round((height - size) / 2)), left: 0, size },
  };
}

function forcedHinge(preview, width, height) {
  if (preview === 'flex') {
    const size = 28;
    return {
      posture: 'flex',
      hinge: { orientation: 'horizontal', top: Math.max(0, Math.round((height - size) / 2)), left: 0, size },
    };
  }
  if (preview === 'book') {
    const size = 24;
    return {
      posture: 'book',
      hinge: { orientation: 'vertical', top: 0, left: Math.max(0, Math.round((width - size) / 2)), size },
    };
  }
  return null;
}

// native: { posture, hinge, multiWindow, cover? } from the Android WindowManager bridge.
// preview: "flex" | "book" | "cover" from ?fold=, ignored when the bridge is present.
export function classifyLayout({
  width = 0,
  height = 0,
  preview = null,
  native = null,
  segments = null,
  devicePosture = null,
} = {}) {
  const windowClass = windowSizeClass(width);
  const heightClass = heightSizeClass(height);
  let posture = 'flat';
  let hinge = null;
  let cover = isCoverViewport(width, height);
  const multiWindow = !!(native && native.multiWindow);

  if (native && (native.posture === 'flat' || native.posture === 'flex' || native.posture === 'book')) {
    posture = native.posture;
    hinge = native.hinge || null;
    if (posture === 'flex' || posture === 'book') cover = false;
    if (typeof native.cover === 'boolean') cover = native.cover;
  } else if (preview === 'cover') {
    cover = true;
  } else if (preview === 'flex' || preview === 'book') {
    const forced = forcedHinge(preview, width, height);
    posture = forced.posture;
    hinge = forced.hinge;
    cover = false;
  } else if (devicePosture === 'folded' || (segments && segments.length >= 2 && devicePosture === 'folded')) {
    const detected = postureFromSegments(segments) || postureFromDevicePosture(devicePosture, width, height);
    if (detected) {
      posture = detected.posture;
      hinge = detected.hinge;
      cover = false;
    }
  } else if (segments && segments.length >= 2) {
    const detected = postureFromSegments(segments);
    if (detected && detected.hinge.size > 0 && detected.hinge.size < 160) {
      posture = detected.posture;
      hinge = detected.hinge;
      cover = false;
    }
  }

  return { windowClass, heightClass, posture, hinge, cover, multiWindow };
}
