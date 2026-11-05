/* copies the site into www/, which Capacitor packs inside the app */
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..'), www = path.join(__dirname, 'www');
fs.rmSync(www, { recursive:true, force:true });
fs.mkdirSync(www, { recursive:true });
for (const f of ['index.html', 'config.js', 'manifest.webmanifest']) fs.copyFileSync(path.join(root, f), path.join(www, f));
fs.cpSync(path.join(root, 'icons'), path.join(www, 'icons'), { recursive:true });
