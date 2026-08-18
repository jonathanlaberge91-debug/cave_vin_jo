#!/usr/bin/env bash
# Deploiement complet de l'app web.
#   bash tool/deploy.sh
#
# Ne PAS deployer a la main sans l'etape « empreintes » : c'est elle qui donne
# aux gros fichiers un nom qui change a chaque build, ce qui permet au
# navigateur de les garder en cache un an sans jamais servir une vieille
# version.
set -e
cd "$(dirname "$0")/.."

echo "== 1/4 Logo du splash =="
dart run tool/optimize_splash.dart

echo "== 2/4 Build web =="
rm -rf build/web
flutter build web --release

echo "== 3/4 Empreintes =="
node tool/fingerprint_web.js

echo "== 4/4 Deploiement =="
firebase deploy --only hosting --project cave-vin-jo
