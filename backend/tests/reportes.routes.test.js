const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const app = require('../src/app');

function solicitar(server, metodo, ruta) {
  const { port } = server.address();
  return new Promise((resolve, reject) => {
    const request = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path: ruta,
        method: metodo,
      },
      (response) => {
        response.resume();
        response.on('end', () => resolve(response.statusCode));
      },
    );
    request.on('error', reject);
    request.end();
  });
}

test('las rutas de reportes requieren JWT antes de acceder a MySQL', async (t) => {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  }));

  assert.equal(await solicitar(server, 'POST', '/api/reportes'), 401);
  assert.equal(await solicitar(server, 'GET', '/api/reportes'), 401);
  assert.equal(await solicitar(server, 'GET', '/api/reportes/1'), 401);
});
