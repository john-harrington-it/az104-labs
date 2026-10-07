// Tiny Node.js app for AZ-104 lab 08. App Service tells the app which port to use in PORT.
const http = require('http');

const port = process.env.PORT || 8080;
const slot = process.env.LAB_SLOT_NAME || 'production';

http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<h1>AZ-104 lab 08</h1>
<p>Served by App Service instance <code>${process.env.WEBSITE_INSTANCE_ID || 'local'}</code></p>
<p>Slot: <strong>${slot}</strong></p>`);
}).listen(port, () => console.log(`Listening on ${port}`));
