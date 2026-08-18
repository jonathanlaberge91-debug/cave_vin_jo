#!/usr/bin/env node
// Empreinte les gros fichiers statiques de build/web pour qu'ils puissent etre
// mis en cache « pour toujours » par le navigateur SANS jamais servir une
// vieille version : a chaque build, le nom du fichier change.
//
//   main.dart.js      -> main.<empreinte>.dart.js   (reference dans flutter_bootstrap.js)
//   splash-logo.jpg   -> splash-logo.<empreinte>.jpg (reference dans index.html)
//
// A lancer APRES `flutter build web --release` (voir tool/deploy.sh).
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const dir = path.join(__dirname, '..', 'build', 'web');
const hash = (f) =>
  crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex').slice(0, 12);

function fingerprint(file, makeName, refFiles) {
  const src = path.join(dir, file);
  if (!fs.existsSync(src)) {
    console.error(`  ! ${file} introuvable, ignore`);
    return;
  }
  const nom = makeName(hash(src));
  fs.renameSync(src, path.join(dir, nom));
  for (const ref of refFiles) {
    const p = path.join(dir, ref);
    if (!fs.existsSync(p)) continue;
    const avant = fs.readFileSync(p, 'utf8');
    const apres = avant.split(file).join(nom);
    if (avant !== apres) fs.writeFileSync(p, apres);
  }
  console.log(`  ${file} -> ${nom}`);
}

console.log('Empreintes :');
fingerprint('main.dart.js', (h) => `main.${h}.dart.js`, ['flutter_bootstrap.js']);
fingerprint('splash-logo.jpg', (h) => `splash-logo.${h}.jpg`, ['index.html']);
