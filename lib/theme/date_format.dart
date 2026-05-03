const monthsFr = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String fmtDate(DateTime d) =>
    '${d.day} ${monthsFr[d.month - 1]} ${d.year}';
