const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const outDir = path.join(__dirname, '..', 'assets', 'branding');

function hexToRgba(hex, alpha = 255) {
  const value = hex.replace('#', '');
  return [
    parseInt(value.slice(0, 2), 16),
    parseInt(value.slice(2, 4), 16),
    parseInt(value.slice(4, 6), 16),
    alpha,
  ];
}

function mix(a, b, t) {
  return Math.round(a + (b - a) * t);
}

function mixColor(a, b, t) {
  return [
    mix(a[0], b[0], t),
    mix(a[1], b[1], t),
    mix(a[2], b[2], t),
    mix(a[3], b[3], t),
  ];
}

class Raster {
  constructor(width, height) {
    this.width = width;
    this.height = height;
    this.data = Buffer.alloc(width * height * 4);
  }

  blend(x, y, color) {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return;
    const i = (Math.floor(y) * this.width + Math.floor(x)) * 4;
    const sa = color[3] / 255;
    const da = this.data[i + 3] / 255;
    const oa = sa + da * (1 - sa);
    if (oa <= 0) return;

    this.data[i] = Math.round((color[0] * sa + this.data[i] * da * (1 - sa)) / oa);
    this.data[i + 1] = Math.round((color[1] * sa + this.data[i + 1] * da * (1 - sa)) / oa);
    this.data[i + 2] = Math.round((color[2] * sa + this.data[i + 2] * da * (1 - sa)) / oa);
    this.data[i + 3] = Math.round(oa * 255);
  }
}

function fillRect(r, x, y, w, h, color) {
  const x0 = Math.max(0, Math.floor(x));
  const y0 = Math.max(0, Math.floor(y));
  const x1 = Math.min(r.width, Math.ceil(x + w));
  const y1 = Math.min(r.height, Math.ceil(y + h));
  for (let py = y0; py < y1; py++) {
    for (let px = x0; px < x1; px++) {
      r.blend(px, py, color);
    }
  }
}

function fillRoundedRect(r, x, y, w, h, radius, colorOrGradient) {
  const x0 = Math.max(0, Math.floor(x));
  const y0 = Math.max(0, Math.floor(y));
  const x1 = Math.min(r.width, Math.ceil(x + w));
  const y1 = Math.min(r.height, Math.ceil(y + h));

  for (let py = y0; py < y1; py++) {
    for (let px = x0; px < x1; px++) {
      const cx = Math.max(x + radius, Math.min(px + 0.5, x + w - radius));
      const cy = Math.max(y + radius, Math.min(py + 0.5, y + h - radius));
      const dx = px + 0.5 - cx;
      const dy = py + 0.5 - cy;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist <= radius) {
        const color =
          typeof colorOrGradient === 'function'
            ? colorOrGradient((py - y) / h, (px - x) / w)
            : colorOrGradient;
        r.blend(px, py, color);
      }
    }
  }
}

function pointInPolygon(x, y, points) {
  let inside = false;
  for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
    const xi = points[i][0];
    const yi = points[i][1];
    const xj = points[j][0];
    const yj = points[j][1];
    const intersect = yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}

function fillPolygon(r, points, color) {
  const xs = points.map((p) => p[0]);
  const ys = points.map((p) => p[1]);
  const x0 = Math.max(0, Math.floor(Math.min(...xs)));
  const y0 = Math.max(0, Math.floor(Math.min(...ys)));
  const x1 = Math.min(r.width, Math.ceil(Math.max(...xs)));
  const y1 = Math.min(r.height, Math.ceil(Math.max(...ys)));

  for (let py = y0; py <= y1; py++) {
    for (let px = x0; px <= x1; px++) {
      if (pointInPolygon(px + 0.5, py + 0.5, points)) {
        r.blend(px, py, color);
      }
    }
  }
}

function distanceToSegment(px, py, ax, ay, bx, by) {
  const dx = bx - ax;
  const dy = by - ay;
  if (dx === 0 && dy === 0) return Math.hypot(px - ax, py - ay);
  const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

function strokeLine(r, ax, ay, bx, by, width, color) {
  const pad = width / 2 + 2;
  const x0 = Math.max(0, Math.floor(Math.min(ax, bx) - pad));
  const y0 = Math.max(0, Math.floor(Math.min(ay, by) - pad));
  const x1 = Math.min(r.width, Math.ceil(Math.max(ax, bx) + pad));
  const y1 = Math.min(r.height, Math.ceil(Math.max(ay, by) + pad));

  for (let py = y0; py <= y1; py++) {
    for (let px = x0; px <= x1; px++) {
      if (distanceToSegment(px + 0.5, py + 0.5, ax, ay, bx, by) <= width / 2) {
        r.blend(px, py, color);
      }
    }
  }
}

function fillCircle(r, cx, cy, radius, color) {
  const x0 = Math.max(0, Math.floor(cx - radius));
  const y0 = Math.max(0, Math.floor(cy - radius));
  const x1 = Math.min(r.width, Math.ceil(cx + radius));
  const y1 = Math.min(r.height, Math.ceil(cy + radius));
  for (let py = y0; py <= y1; py++) {
    for (let px = x0; px <= x1; px++) {
      if (Math.hypot(px + 0.5 - cx, py + 0.5 - cy) <= radius) {
        r.blend(px, py, color);
      }
    }
  }
}

function drawScaled(targetSize, drawBackground) {
  const scale = targetSize / 1024;
  const r = new Raster(targetSize, targetSize);
  const s = (v) => v * scale;
  const c = (hex, alpha) => hexToRgba(hex, alpha);

  const blueTop = c('#1673D1');
  const blueBottom = c('#0B4FA3');
  const deepBlue = c('#083F85');
  const paleBlue = c('#DDEFFF');
  const white = c('#FFFFFF');
  const green = c('#2EAD5B');
  const greenDark = c('#12813A');
  const shadow = c('#062D5D', 72);

  if (drawBackground) {
    fillRoundedRect(r, s(64), s(64), s(896), s(896), s(220), (t, x) =>
      mixColor(blueTop, blueBottom, Math.min(1, t * 0.85 + x * 0.15)),
    );
    fillCircle(r, s(792), s(214), s(170), c('#5DB3FF', 42));
    fillCircle(r, s(228), s(798), s(150), c('#00346E', 45));
  }

  fillRoundedRect(r, s(246), s(344), s(532), s(424), s(70), shadow);
  fillPolygon(
    r,
    [
      [s(310), s(258)],
      [s(710), s(258)],
      [s(786), s(344)],
      [s(246), s(344)],
    ],
    paleBlue,
  );
  fillRoundedRect(r, s(246), s(322), s(532), s(416), s(68), white);
  fillPolygon(
    r,
    [
      [s(246), s(322)],
      [s(786), s(322)],
      [s(710), s(258)],
      [s(310), s(258)],
    ],
    c('#F3FAFF'),
  );

  fillRoundedRect(r, s(468), s(258), s(88), s(208), s(20), green);
  fillPolygon(
    r,
    [
      [s(432), s(322)],
      [s(516), s(258)],
      [s(596), s(322)],
    ],
    c('#34C86A'),
  );

  strokeLine(r, s(286), s(342), s(740), s(342), s(24), c('#0A55A8', 185));
  strokeLine(r, s(286), s(516), s(740), s(516), s(14), c('#E0EEF8'));

  const barcodeX = [316, 344, 376, 416, 446];
  const barcodeW = [12, 18, 10, 22, 12];
  for (let i = 0; i < barcodeX.length; i++) {
    fillRoundedRect(r, s(barcodeX[i]), s(574), s(barcodeW[i]), s(112), s(5), deepBlue);
  }

  strokeLine(r, s(522), s(622), s(592), s(690), s(58), greenDark);
  strokeLine(r, s(592), s(690), s(724), s(530), s(58), greenDark);
  strokeLine(r, s(522), s(622), s(592), s(690), s(38), green);
  strokeLine(r, s(592), s(690), s(724), s(530), s(38), green);

  return r;
}

function crc32(buffer) {
  let crc = ~0;
  for (const byte of buffer) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) {
      crc = crc & 1 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
    }
  }
  return ~crc >>> 0;
}

function chunk(type, data) {
  const typeBuffer = Buffer.from(type);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])));
  return Buffer.concat([length, typeBuffer, data, crc]);
}

function savePng(filePath, raster) {
  const raw = Buffer.alloc((raster.width * 4 + 1) * raster.height);
  for (let y = 0; y < raster.height; y++) {
    const rawRow = y * (raster.width * 4 + 1);
    raw[rawRow] = 0;
    raster.data.copy(raw, rawRow + 1, y * raster.width * 4, (y + 1) * raster.width * 4);
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(raster.width, 0);
  ihdr.writeUInt32BE(raster.height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  const png = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
  fs.writeFileSync(filePath, png);
}

function saveSvgFiles() {
  const markSvg = `<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="64" y="64" width="896" height="896" rx="220" fill="url(#bg)"/>
  <circle cx="792" cy="214" r="170" fill="#5DB3FF" fill-opacity=".18"/>
  <circle cx="228" cy="798" r="150" fill="#00346E" fill-opacity=".18"/>
  <rect x="246" y="344" width="532" height="424" rx="70" fill="#062D5D" fill-opacity=".28"/>
  <path d="M310 258h400l76 86H246l64-86Z" fill="#DDEFFF"/>
  <rect x="246" y="322" width="532" height="416" rx="68" fill="#fff"/>
  <path d="M246 322h540l-76-64H310l-64 64Z" fill="#F3FAFF"/>
  <rect x="468" y="258" width="88" height="208" rx="20" fill="#2EAD5B"/>
  <path d="M432 322l84-64 80 64H432Z" fill="#34C86A"/>
  <path d="M286 342h454" stroke="#0A55A8" stroke-width="24" stroke-linecap="round"/>
  <path d="M286 516h454" stroke="#E0EEF8" stroke-width="14" stroke-linecap="round"/>
  <rect x="316" y="574" width="12" height="112" rx="5" fill="#083F85"/>
  <rect x="344" y="574" width="18" height="112" rx="5" fill="#083F85"/>
  <rect x="376" y="574" width="10" height="112" rx="5" fill="#083F85"/>
  <rect x="416" y="574" width="22" height="112" rx="5" fill="#083F85"/>
  <rect x="446" y="574" width="12" height="112" rx="5" fill="#083F85"/>
  <path d="M522 622l70 68 132-160" stroke="#12813A" stroke-width="58" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M522 622l70 68 132-160" stroke="#2EAD5B" stroke-width="38" stroke-linecap="round" stroke-linejoin="round"/>
  <defs>
    <linearGradient id="bg" x1="176" y1="106" x2="848" y2="918" gradientUnits="userSpaceOnUse">
      <stop stop-color="#1673D1"/>
      <stop offset="1" stop-color="#0B4FA3"/>
    </linearGradient>
  </defs>
</svg>
`;

  const logoSvg = `<?xml version="1.0" encoding="UTF-8"?>
<svg width="1800" height="520" viewBox="0 0 1800 520" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="40" y="40" width="440" height="440" rx="112" fill="url(#bg)"/>
  <circle cx="398" cy="114" r="76" fill="#5DB3FF" fill-opacity=".18"/>
  <path d="M167 165h184l35 40H138l29-40Z" fill="#DDEFFF"/>
  <rect x="138" y="195" width="248" height="194" rx="34" fill="#fff"/>
  <path d="M138 195h248l-35-30H167l-29 30Z" fill="#F3FAFF"/>
  <rect x="242" y="165" width="40" height="98" rx="10" fill="#2EAD5B"/>
  <path d="M224 195l38-30 38 30h-76Z" fill="#34C86A"/>
  <path d="M156 205h212" stroke="#0A55A8" stroke-width="12" stroke-linecap="round"/>
  <rect x="170" y="312" width="7" height="52" rx="3.5" fill="#083F85"/>
  <rect x="186" y="312" width="10" height="52" rx="5" fill="#083F85"/>
  <rect x="204" y="312" width="6" height="52" rx="3" fill="#083F85"/>
  <rect x="226" y="312" width="12" height="52" rx="5" fill="#083F85"/>
  <path d="M266 334l32 31 61-74" stroke="#12813A" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M266 334l32 31 61-74" stroke="#2EAD5B" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>
  <text x="560" y="250" fill="#083F85" font-family="Inter, Segoe UI, Arial, sans-serif" font-size="132" font-weight="800">Baixa</text>
  <text x="560" y="374" fill="#2EAD5B" font-family="Inter, Segoe UI, Arial, sans-serif" font-size="132" font-weight="800">Fácil</text>
  <text x="930" y="374" fill="#496173" font-family="Inter, Segoe UI, Arial, sans-serif" font-size="44" font-weight="600">entrega confirmada</text>
  <defs>
    <linearGradient id="bg" x1="95" y1="60" x2="425" y2="460" gradientUnits="userSpaceOnUse">
      <stop stop-color="#1673D1"/>
      <stop offset="1" stop-color="#0B4FA3"/>
    </linearGradient>
  </defs>
</svg>
`;

  fs.writeFileSync(path.join(outDir, 'baixa_facil_mark.svg'), markSvg);
  fs.writeFileSync(path.join(outDir, 'baixa_facil_logo.svg'), logoSvg);
}

fs.mkdirSync(outDir, { recursive: true });
saveSvgFiles();
savePng(path.join(outDir, 'baixa_facil_mark.png'), drawScaled(1024, true));
savePng(path.join(outDir, 'baixa_facil_mark_transparent.png'), drawScaled(1024, false));

const androidIconSizes = [
  ['mipmap-mdpi', 48],
  ['mipmap-hdpi', 72],
  ['mipmap-xhdpi', 96],
  ['mipmap-xxhdpi', 144],
  ['mipmap-xxxhdpi', 192],
];

for (const [folder, size] of androidIconSizes) {
  const iconDir = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'res', folder);
  fs.mkdirSync(iconDir, { recursive: true });
  savePng(path.join(iconDir, 'ic_baixa_facil.png'), drawScaled(size, true));
}
