const TIPOS_REPORTE = [
  'residuosAcumulados',
  'contenedorLleno',
  'faltaRecoleccion',
  'puntoIlegal',
  'otro',
];

function validarCreacionReporte(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    return ['El cuerpo de la solicitud debe ser un objeto'];
  }

  const errores = [];

  if (typeof body.tipo !== 'string' || !TIPOS_REPORTE.includes(body.tipo)) {
    errores.push('El tipo de incidencia no es válido');
  }

  if (typeof body.descripcion !== 'string' || body.descripcion.trim().length < 10) {
    errores.push('La descripción debe tener al menos 10 caracteres');
  }

  if (typeof body.zona !== 'string' || body.zona.trim().length === 0) {
    errores.push('La zona o dirección es obligatoria');
  } else if (body.zona.trim().length > 200) {
    errores.push('La zona o dirección no puede superar 200 caracteres');
  }

  const tieneLatitud = body.latitud !== undefined && body.latitud !== null;
  const tieneLongitud = body.longitud !== undefined && body.longitud !== null;
  if (tieneLatitud !== tieneLongitud) {
    errores.push('Debes enviar latitud y longitud juntas');
  } else if (tieneLatitud) {
    if (
      typeof body.latitud !== 'number' ||
      !Number.isFinite(body.latitud) ||
      body.latitud < -90 ||
      body.latitud > 90
    ) {
      errores.push('La latitud no es válida');
    }
    if (
      typeof body.longitud !== 'number' ||
      !Number.isFinite(body.longitud) ||
      body.longitud < -180 ||
      body.longitud > 180
    ) {
      errores.push('La longitud no es válida');
    }
  }

  return errores;
}

module.exports = { validarCreacionReporte };
