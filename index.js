const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/power-bridge.sh') {
    const filePath = path.join(__dirname, 'power-bridge.sh');

    fs.stat(filePath, (err, stats) => {
      if (err) {
        console.error('File not found or error reading stats:', err);
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('File Not Found');
        return;
      }

      res.writeHead(200, {
        'Content-Type': 'text/plain', // plain text is safer for curl piping
        'Content-Length': stats.size
      });

      const readStream = fs.createReadStream(filePath);
      readStream.pipe(res);
    });
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

server.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
