/* copies the site into www/, which Capacitor packs inside the app */
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..'), www = path.join(__dirname, 'www');
fs.rmSync(www, { recursive:true, force:true });
fs.mkdirSync(www, { recursive:true });
for (const f of ['index.html', 'config.js', 'manifest.webmanifest', 'privacy.html', 'terms.html']) fs.copyFileSync(path.join(root, f), path.join(www, f));
for (const d of ['icons', 'vendor']) fs.cpSync(path.join(root, d), path.join(www, d), { recursive:true });
