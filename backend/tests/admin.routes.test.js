const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const pool = require('../src/config/db');
const { generarToken } = require('../src/config/jwt');
const app = require('../src/app');

function solicitar(server, authorization) {
  return new Promise((resolve, reject) => {
    const request = http.request(
      {
        hostname: '127.0.0.1',
        port: server.address().port,
        path: '/api/admin/dashboard',
        method: 'GET',
        headers: authorization ? { Authorization: authorization } : {},
      },
      (response) => {
        let body = '';
        response.setEncoding('utf8');
        response.on('data', (parte) => {
          body += parte;
        });
        response.on('end', () => resolve({ statusCode: response.statusCode, body }));
      },
    );
    request.on('error', reject);
    request.end();
  });
}

test('el endpoint del panel exige JWT y rol administrativo obtenido de MySQL', async (t) => {
  const ejecutarOriginal = pool.execute;
  pool.execute = async (_sql, [id]) => [[{
    id,
    correo: 'cuenta@example.test',
    rol: id === 1 ? 'admin' : 'ciudadano',
  }]];
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(async () => {
    pool.execute = ejecutarOriginal;
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  });

  const sinToken = await solicitar(server);
  assert.equal(sinToken.statusCode, 401);

  const tokenCiudadano = generarToken({ id: 2, correo: 'cuenta@example.test' });
  const ciudadano = await solicitar(server, `Bearer ${tokenCiudadano}`);
  assert.equal(ciudadano.statusCode, 403);

  const tokenAdmin = generarToken({ id: 1, correo: 'cuenta@example.test' });
  const administrador = await solicitar(server, `Bearer ${tokenAdmin}`);
  assert.equal(administrador.statusCode, 200);
  assert.deepEqual(JSON.parse(administrador.body), {
    usuario: {
      id: 1,
      correo: 'cuenta@example.test',
      rol: 'admin',
    },
  });
});
