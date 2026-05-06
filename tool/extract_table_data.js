// Extract only the fields needed for the table mockup
const data = require('./wines_data.json');
const fs = require('fs');

const bottlesByWine = {};
for (const b of data.bottles) {
  if (!bottlesByWine[b.wineId]) bottlesByWine[b.wineId] = [];
  bottlesByWine[b.wineId].push(b);
}

const rows = [];
for (const w of data.wines) {
  const bottles = bottlesByWine[w.id] || [];
  if (bottles.length === 0) continue;

  const formats = [...new Set(bottles.map(b => b.format))];
  const prices = bottles.map(b => b.purchasePrice).filter(p => p != null);
  const avgPrice = prices.length ? prices.reduce((a, b) => a + b, 0) / prices.length : null;
  const marketValues = bottles.map(b => b.marketValue).filter(v => v != null);
  const totalValue = bottles.reduce((s, b) => s + (b.marketValue || b.purchasePrice || 0), 0);

  rows.push({
    name: w.name || '',
    producer: w.producer || '',
    vintage: w.vintage || null,
    appellation: w.appellation || '',
    region: w.region || '',
    country: w.country || '',
    village: w.village || '',
    climat: w.climat || '',
    domaine: w.domaine || '',
    grapes: w.grapes || '',
    alcohol: w.alcohol || null,
    type: w.type || 'red',
    rating: w.rating || null,
    drinkFrom: w.drinkFrom || null,
    drinkPeak: w.drinkPeak || null,
    drinkTo: w.drinkTo || null,
    qty: bottles.length,
    format: formats.length > 1 ? 'Mixte' : (formats[0] || '750 ML'),
    price: avgPrice,
    mixedPrices: new Set(prices).size > 1,
    totalValue: totalValue,
    photoUrl: w.photoUrl || null,
  });
}

fs.writeFileSync('tool/table_rows.json', JSON.stringify(rows, null, 2));
console.log(`${rows.length} rows ready`);
rows.forEach(r => console.log(` - ${r.name} (${r.vintage||'NV'}) | ${r.appellation} | ${r.region} | qty:${r.qty}`));
