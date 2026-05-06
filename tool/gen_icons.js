// Generates PWA icons from assets/images/logo.png
const sharp = require('C:/Users/jonat/AppData/Roaming/npm/node_modules/sharp-cli/node_modules/sharp');
const path = require('path');

const SRC = path.resolve('assets/images/logo.png');
const OUT = path.resolve('web/icons');
const DARK_BG = { r: 14, g: 12, b: 10, alpha: 1 };  // #0E0C0A
const TRANSPARENT = { r: 0, g: 0, b: 0, alpha: 0 };

async function makeIcon(size, dest, bg, safePct = 1.0) {
  const inner = Math.round(size * safePct);
  await sharp(SRC)
    .resize(inner, inner, { fit: 'contain', background: TRANSPARENT, kernel: 'lanczos3' })
    .extend({
      top: Math.floor((size - inner) / 2),
      bottom: Math.ceil((size - inner) / 2),
      left: Math.floor((size - inner) / 2),
      right: Math.ceil((size - inner) / 2),
      background: bg,
    })
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(path.join(OUT, dest));
  console.log(`  ${dest} (${size}x${size})`);
}

(async () => {
  console.log('Generating PWA icons from logo.png (697x1145)...');

  // Regular icons — transparent background, logo centered
  await makeIcon(512, 'Icon-512.png', TRANSPARENT);
  await makeIcon(192, 'Icon-192.png', TRANSPARENT);

  // Maskable icons — dark background, logo scaled to 80% safe zone
  await makeIcon(512, 'Icon-maskable-512.png', DARK_BG, 0.80);
  await makeIcon(192, 'Icon-maskable-192.png', DARK_BG, 0.80);

  // apple-touch-icon — white background (iOS doesn't support transparency well)
  const APPLE_BG = { r: 255, g: 250, b: 240, alpha: 1 }; // #FFFAF0 warm off-white
  await makeIcon(180, 'apple-touch-icon.png', APPLE_BG, 0.75);

  // favicon — transparent
  await sharp(SRC)
    .resize(64, 64, { fit: 'contain', background: TRANSPARENT, kernel: 'lanczos3' })
    .png({ compressionLevel: 9 })
    .toFile(path.resolve('web/favicon.png'));
  console.log('  favicon.png (64x64)');

  console.log('Done.');
})();
