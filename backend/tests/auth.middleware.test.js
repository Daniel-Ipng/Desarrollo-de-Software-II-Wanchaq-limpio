const test = require('node:test');
const assert = require('node:assert/strict');
const pool = require('../src/config/db');
const { generarToken } = require('../src/config/jwt');
const { autenticar } = require('../src/middleware/auth.middleware');
const { autorizarRol } = require('../src/middleware/authorization.middleware');

function crearRespuesta() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

test('autenticar obtiene el rol desde MySQL e ignora el rol del JWT', async () => {
  const ejecutarOriginal = pool.execute;
  let consulta;
  pool.execute = async (sql, parametros) => {
    consulta = { sql, parametros };
    return [[{ id: 8, correo: 'admin@example.test', rol: 'ciudadano' }]];
  };

  try {
    const req = {
      headers: {
        authorization: `Bearer ${generarToken({
          id: 8,
          correo: 'token@example.test',
          rol: 'administrador',
        })}`,
      },
    };
    const res = crearRespuesta();
    let siguiente = false;

    await autenticar(req, res, () => {
      siguiente = true;
    });

    assert.equal(siguiente, true);
    assert.match(consulta.sql, /SELECT id, correo, rol FROM usuarios/);
    assert.deepEqual(consulta.parametros, [8]);
    assert.deepEqual(req.usuario, {
      id: 8,
      correo: 'admin@example.test',
      rol: 'ciudadano',
    });
  } finally {
    pool.execute = ejecutarOriginal;
  }
});

test('autenticar rechaza tokens sin un usuario vigente', async () => {
  const ejecutarOriginal = pool.execute;
  pool.execute = async () => [[]];

  try {
    const res = crearRespuesta();
    let siguiente = false;
    await autenticar(
      {
        headers: {
          authorization: `Bearer ${generarToken({ id: 99, correo: 'x@example.test' })}`,
        },
      },
      res,
      () => {
        siguiente = true;
      },
    );

    assert.equal(res.statusCode, 401);
    assert.equal(siguiente, false);
  } finally {
    pool.execute = ejecutarOriginal;
  }
});

test('autorizarRol permite solo roles expresamente asignados', () => {
  const res = crearRespuesta();
  let siguiente = false;
  autorizarRol('administrador')(
    { usuario: { rol: 'ciudadano' } },
    res,
    () => {
      siguiente = true;
    },
  );

  assert.equal(res.statusCode, 403);
  assert.equal(siguiente, false);
});
