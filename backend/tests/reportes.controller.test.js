const test = require('node:test');
const assert = require('node:assert/strict');
const pool = require('../src/config/db');
const { crear, listar, obtener } = require('../src/controllers/reportes.controller');

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

test('crear obtiene el propietario del JWT e ignora ciudadano_id del body', async () => {
  const ejecutarOriginal = pool.execute;
  const llamadas = [];
  pool.execute = async (sql, parametros) => {
    llamadas.push({ sql, parametros });
    if (sql.includes('INSERT INTO reportes')) return [{ insertId: 12 }];
    return [[{
      id: 12,
      ciudadano_id: 7,
      tipo: 'otro',
      descripcion: 'Descripción suficiente para el reporte',
      zona: 'Wanchaq',
      latitud: -13.53195,
      longitud: -71.96746,
      estado: 'pendiente',
      creado_en: new Date('2026-01-01T00:00:00.000Z'),
    }]];
  };

  try {
    const respuesta = crearRespuesta();
    await crear(
      {
        usuario: { id: 7 },
        body: {
          ciudadano_id: 99,
          tipo: 'otro',
          descripcion: 'Descripción suficiente para el reporte',
          zona: 'Wanchaq',
          latitud: -13.53195,
          longitud: -71.96746,
        },
      },
      respuesta,
    );

    assert.equal(respuesta.statusCode, 201);
    assert.deepEqual(llamadas[0].parametros, [
      7,
      'otro',
      'Descripción suficiente para el reporte',
      'Wanchaq',
      -13.53195,
      -71.96746,
    ]);
    assert.deepEqual(llamadas[1].parametros, [12, 7]);
    assert.equal(respuesta.body.ciudadano_id, 7);
  } finally {
    pool.execute = ejecutarOriginal;
  }
});

test('listar limita la consulta al ciudadano autenticado', async () => {
  const ejecutarOriginal = pool.execute;
  let llamada;
  pool.execute = async (sql, parametros) => {
    llamada = { sql, parametros };
    return [[]];
  };

  try {
    const respuesta = crearRespuesta();
    await listar({ usuario: { id: 23 } }, respuesta);

    assert.equal(respuesta.statusCode, 200);
    assert.match(llamada.sql, /WHERE ciudadano_id = \?/);
    assert.deepEqual(llamada.parametros, [23]);
  } finally {
    pool.execute = ejecutarOriginal;
  }
});

test('detalle limita por identificador y propietario, y oculta ajenos como 404', async () => {
  const ejecutarOriginal = pool.execute;
  let llamada;
  pool.execute = async (sql, parametros) => {
    llamada = { sql, parametros };
    return [[]];
  };

  try {
    const respuesta = crearRespuesta();
    await obtener({ params: { id: '41' }, usuario: { id: 23 } }, respuesta);

    assert.equal(respuesta.statusCode, 404);
    assert.match(llamada.sql, /WHERE id = \? AND ciudadano_id = \?/);
    assert.deepEqual(llamada.parametros, [41, 23]);
  } finally {
    pool.execute = ejecutarOriginal;
  }
});
