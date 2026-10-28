const test = require('node:test');
const assert = require('node:assert/strict');
const bcrypt = require('bcrypt');
const pool = require('../src/config/db');
const { registro, login } = require('../src/controllers/auth.controller');

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

test('registro fija el rol ciudadano aunque se envíe rol administrador', async () => {
  const ejecutarOriginal = pool.execute;
  const llamadas = [];
  pool.execute = async (sql, parametros) => {
    llamadas.push({ sql, parametros });
    if (sql.includes('FROM zonas WHERE id = ?')) {
      return [[{ id: 3, nombre: 'Wanchaq' }]];
    }
    if (sql.includes('SELECT id FROM usuarios')) return [[]];
    return [{ insertId: 42 }];
  };

  try {
    const respuesta = crearRespuesta();
    await registro(
      {
        body: {
          nombres: 'Persona',
          apellidos: 'De Prueba',
          dni: '12345678',
          correo: 'persona@example.test',
          telefono: '999111222',
          contrasena: 'una-clave-segura',
          zona_id: 3,
          direccion: 'Referencia de prueba',
          rol: 'admin',
        },
      },
      respuesta,
    );

    assert.equal(respuesta.statusCode, 201);
    assert.match(llamadas[2].sql, /password_hash, rol,[\s\S]*'ciudadano'/);
    assert.equal(llamadas[2].parametros.length, 10);
    assert.notEqual(llamadas[2].parametros[5], 'una-clave-segura');
    assert.equal(
      await bcrypt.compare('una-clave-segura', llamadas[2].parametros[5]),
      true,
    );
    assert.equal(respuesta.body.usuario.rol, 'ciudadano');
    assert.equal('password_hash' in respuesta.body.usuario, false);
    assert.equal(respuesta.body.usuario.zona_nombre, 'Wanchaq');
  } finally {
    pool.execute = ejecutarOriginal;
  }
});

test('login incluye el rol consultado al backend y nunca devuelve el hash', async () => {
  const ejecutarOriginal = pool.execute;
  const hash = await bcrypt.hash('una-clave-segura', 4);
  pool.execute = async () => [[{
    id: 21,
    nombres: 'Admin',
    apellidos: 'Eco',
    dni: '87654321',
    correo: 'admin@example.test',
    telefono: null,
    password_hash: hash,
    rol: 'admin',
  }]];

  try {
    const respuesta = crearRespuesta();
    await login(
      {
        body: {
          correo: 'admin@example.test',
          contrasena: 'una-clave-segura',
        },
      },
      respuesta,
    );

    assert.equal(respuesta.statusCode, 200);
    assert.equal(respuesta.body.usuario.rol, 'admin');
    assert.equal('password_hash' in respuesta.body.usuario, false);
  } finally {
    pool.execute = ejecutarOriginal;
  }
});

test('perfil devuelve el rol actual consultado por id autenticado', async () => {
  const ejecutarOriginal = pool.execute;
  let consulta;
  pool.execute = async (sql, parametros) => {
    consulta = { sql, parametros };
    return [[{
      id: 21,
      nombres: 'Admin',
      apellidos: 'Eco',
      dni: '87654321',
      correo: 'admin@example.test',
      telefono: null,
      rol: 'admin',
    }]];
  };

  try {
    const respuesta = crearRespuesta();
    const { perfil } = require('../src/controllers/auth.controller');
    await perfil({ usuario: { id: 21 } }, respuesta);

    assert.equal(respuesta.statusCode, 200);
    assert.match(consulta.sql, /zona_id, z\.nombre AS zona_nombre/);
    assert.match(consulta.sql, /WHERE u\.id = \? AND u\.activo = 1/);
    assert.deepEqual(consulta.parametros, [21]);
    assert.equal(respuesta.body.rol, 'admin');
    assert.equal('password_hash' in respuesta.body, false);
  } finally {
    pool.execute = ejecutarOriginal;
  }
});

test('actualizarPerfil modifica únicamente al usuario autenticado', async () => {
  const ejecutarOriginal = pool.execute;
  const llamadas = [];
  pool.execute = async (sql, parametros) => {
    llamadas.push({ sql, parametros });
    if (sql.includes('FROM zonas WHERE id = ?')) {
      return [[{ id: 3 }]];
    }
    if (sql.startsWith('UPDATE usuarios')) return [{ affectedRows: 1 }];
    return [[{
      id: 21,
      nombres: 'Persona',
      apellidos: 'Actualizada',
      dni: '87654321',
      correo: 'persona@example.test',
      telefono: null,
      rol: 'ciudadano',
      zona_id: 3,
      zona_nombre: 'Wanchaq',
      direccion: 'Nueva referencia',
      latitud_domicilio: null,
      longitud_domicilio: null,
    }]];
  };

  try {
    const { actualizarPerfil } = require('../src/controllers/auth.controller');
    const respuesta = crearRespuesta();
    await actualizarPerfil(
      {
        usuario: { id: 21 },
        body: {
          nombre: 'Persona',
          apellidos: 'Actualizada',
          telefono: '',
          zona_id: 3,
          direccion: 'Nueva referencia',
        },
      },
      respuesta,
    );

    assert.equal(respuesta.statusCode, 200);
    assert.match(llamadas[1].sql, /WHERE id = \? AND activo = 1/);
    assert.deepEqual(llamadas[1].parametros, [
      'Persona',
      'Actualizada',
      null,
      3,
      'Nueva referencia',
      null,
      null,
      21,
    ]);
    assert.equal('password_hash' in respuesta.body, false);
  } finally {
    pool.execute = ejecutarOriginal;
  }
});
