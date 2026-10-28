const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validarRegistro,
  validarActualizacionPerfil,
} = require('../src/validators/auth.validator');

const registroValido = {
  nombres: 'Ciudadana',
  apellidos: 'De Prueba',
  dni: '12345678',
  correo: 'ciudadana@example.test',
  contrasena: 'clave-segura',
  zona_id: 2,
  direccion: 'Referencia domiciliaria',
};

test('registro valida zona y coordenadas domiciliarias opcionales', () => {
  assert.deepEqual(validarRegistro(registroValido), []);
  assert.deepEqual(
    validarRegistro({
      ...registroValido,
      latitud_domicilio: -13.53,
      longitud_domicilio: -71.96,
    }),
    [],
  );
  assert.ok(validarRegistro({ ...registroValido, zona_id: 0 }).length > 0);
  assert.ok(
    validarRegistro({ ...registroValido, latitud_domicilio: 91 }).length > 0,
  );
});

test('perfil no acepta roles enviados por el cliente', () => {
  const perfil = {
    nombre: 'Ciudadana',
    apellidos: 'De Prueba',
    zona_id: 2,
    direccion: 'Referencia domiciliaria',
  };

  assert.deepEqual(validarActualizacionPerfil(perfil), []);
  assert.ok(
    validarActualizacionPerfil({ ...perfil, rol: 'admin' }).some((error) =>
      error.includes('rol'),
    ),
  );
});
