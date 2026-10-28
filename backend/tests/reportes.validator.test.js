const test = require('node:test');
const assert = require('node:assert/strict');
const { validarCreacionReporte } = require('../src/validators/reportes.validator');

const reporteValido = {
  tipo: 'residuosAcumulados',
  descripcion: 'Residuos acumulados junto al parque central.',
  zona: 'Av. Garcilaso, cuadra 3',
};

test('acepta los campos válidos utilizados por Flutter', () => {
  assert.deepEqual(validarCreacionReporte(reporteValido), []);
});

test('rechaza cuerpos que no sean objetos', () => {
  assert.ok(validarCreacionReporte(null).length > 0);
  assert.ok(validarCreacionReporte([]).length > 0);
});

test('acepta únicamente los tipos existentes en Flutter', () => {
  const tipos = [
    'residuosAcumulados',
    'contenedorLleno',
    'faltaRecoleccion',
    'puntoIlegal',
    'otro',
  ];

  for (const tipo of tipos) {
    assert.deepEqual(validarCreacionReporte({ ...reporteValido, tipo }), []);
  }
  assert.ok(
    validarCreacionReporte({ ...reporteValido, tipo: 'categoriaInexistente' }).length > 0,
  );
});

test('valida descripción y zona antes de ejecutar consultas', () => {
  assert.ok(
    validarCreacionReporte({ ...reporteValido, descripcion: 'corto' }).length > 0,
  );
  assert.ok(validarCreacionReporte({ ...reporteValido, zona: ' ' }).length > 0);
  assert.ok(
    validarCreacionReporte({ ...reporteValido, zona: 'z'.repeat(201) }).length > 0,
  );
});

test('acepta coordenadas opcionales dentro de sus rangos', () => {
  assert.deepEqual(
    validarCreacionReporte({
      ...reporteValido,
      latitud: -13.53195,
      longitud: -71.96746,
    }),
    [],
  );
  assert.deepEqual(validarCreacionReporte(reporteValido), []);
});

test('rechaza coordenadas incompletas o fuera de rango', () => {
  assert.ok(
    validarCreacionReporte({ ...reporteValido, latitud: -13.5 }).length > 0,
  );
  assert.ok(
    validarCreacionReporte({
      ...reporteValido,
      latitud: 91,
      longitud: -71,
    }).length > 0,
  );
});
