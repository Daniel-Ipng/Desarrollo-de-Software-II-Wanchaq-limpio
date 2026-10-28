const test = require('node:test');
const assert = require('node:assert/strict');
const pool = require('../src/config/db');
const { listarActivas } = require('../src/controllers/zonas.controller');

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

test('lista zonas activas sin exponer columnas internas', async () => {
  const ejecutarOriginal = pool.execute;
  let consulta;
  pool.execute = async (sql, parametros) => {
    consulta = { sql, parametros };
    return [[{ id: 4, nombre: 'Wanchaq', descripcion: 'Distrito', activo: 1 }]];
  };

  try {
    const respuesta = crearRespuesta();
    await listarActivas({}, respuesta);

    assert.equal(respuesta.statusCode, 200);
    assert.match(consulta.sql, /WHERE activo = 1/);
    assert.deepEqual(consulta.parametros, []);
    assert.deepEqual(respuesta.body, [
      { id: 4, nombre: 'Wanchaq', descripcion: 'Distrito' },
    ]);
  } finally {
    pool.execute = ejecutarOriginal;
  }
});
