/**
 * Validaciones para los datos de autenticación.
 *
 * Cada función recibe el body de la petición y devuelve
 * un array de mensajes de error. Si está vacío, la validación pasó.
 */

/**
 * Valida los campos requeridos para el registro de un ciudadano.
 * Campos: nombres, apellidos, dni (8 dígitos), correo, contrasena (≥8 chars).
 * Teléfono es opcional.
 */
function validarRegistro(body) {
  const errores = [];

  if (!esObjetoValido(body)) {
    return ['El cuerpo de la solicitud debe ser un objeto'];
  }

  if (!body.nombres || typeof body.nombres !== 'string' || body.nombres.trim().length === 0) {
    errores.push('El campo "nombres" es obligatorio');
  } else if (body.nombres.trim().length > 100) {
    errores.push('El campo "nombres" no puede superar 100 caracteres');
  }

  if (!body.apellidos || typeof body.apellidos !== 'string' || body.apellidos.trim().length === 0) {
    errores.push('El campo "apellidos" es obligatorio');
  } else if (body.apellidos.trim().length > 100) {
    errores.push('El campo "apellidos" no puede superar 100 caracteres');
  }

  if (!body.dni || typeof body.dni !== 'string' || !/^\d{8}$/.test(body.dni)) {
    errores.push('El DNI debe contener exactamente 8 dígitos numéricos');
  }

  if (!body.correo || typeof body.correo !== 'string') {
    errores.push('El campo "correo" es obligatorio');
  } else {
    const correo = body.correo.trim();
    const regexCorreo = /^[\w.+-]+@[\w-]+\.[\w.]+$/;
    if (correo.length > 150) {
      errores.push('El campo "correo" no puede superar 150 caracteres');
    } else if (!regexCorreo.test(correo)) {
      errores.push('El correo electrónico no tiene un formato válido');
    }
  }

  if (!body.contrasena || typeof body.contrasena !== 'string') {
    errores.push('El campo "contrasena" es obligatorio');
  } else if (body.contrasena.length < 8) {
    errores.push('La contraseña debe tener al menos 8 caracteres');
  }

  if (body.telefono !== undefined) {
    if (typeof body.telefono !== 'string') {
      errores.push('El campo "telefono" debe ser una cadena');
    } else if (body.telefono.trim().length > 20) {
      errores.push('El campo "telefono" no puede superar 20 caracteres');
    }
  }

  errores.push(...validarUbicacionDomicilio(body));

  return errores;
}

/**
 * Valida los campos requeridos para iniciar sesión.
 */
function validarLogin(body) {
  const errores = [];

  if (!esObjetoValido(body)) {
    return ['El cuerpo de la solicitud debe ser un objeto'];
  }

  if (!body.correo || typeof body.correo !== 'string' || body.correo.trim().length === 0) {
    errores.push('El campo "correo" es obligatorio');
  } else if (body.correo.trim().length > 150) {
    errores.push('El campo "correo" no puede superar 150 caracteres');
  }

  if (!body.contrasena || typeof body.contrasena !== 'string' || body.contrasena.length === 0) {
    errores.push('El campo "contrasena" es obligatorio');
  }

  return errores;
}

function esObjetoValido(body) {
  return body !== null && typeof body === 'object' && !Array.isArray(body);
}

function validarUbicacionDomicilio(body) {
  const errores = [];

  if (!Number.isSafeInteger(body.zona_id) || body.zona_id <= 0) {
    errores.push('Selecciona una zona de residencia válida');
  }

  if (typeof body.direccion !== 'string' || body.direccion.trim().length === 0) {
    errores.push('La dirección o referencia del domicilio es obligatoria');
  }

  const tieneLatitud =
    body.latitud_domicilio !== undefined && body.latitud_domicilio !== null;
  const tieneLongitud =
    body.longitud_domicilio !== undefined && body.longitud_domicilio !== null;
  if (tieneLatitud !== tieneLongitud) {
    errores.push('Debes enviar juntas las coordenadas del domicilio');
  } else if (tieneLatitud) {
    if (
      typeof body.latitud_domicilio !== 'number' ||
      !Number.isFinite(body.latitud_domicilio) ||
      body.latitud_domicilio < -90 ||
      body.latitud_domicilio > 90
    ) {
      errores.push('La latitud del domicilio no es válida');
    }
    if (
      typeof body.longitud_domicilio !== 'number' ||
      !Number.isFinite(body.longitud_domicilio) ||
      body.longitud_domicilio < -180 ||
      body.longitud_domicilio > 180
    ) {
      errores.push('La longitud del domicilio no es válida');
    }
  }

  return errores;
}

function validarActualizacionPerfil(body) {
  if (!esObjetoValido(body)) {
    return ['El cuerpo de la solicitud debe ser un objeto'];
  }

  const errores = [];
  for (const campo of ['nombre', 'apellidos']) {
    if (typeof body[campo] !== 'string' || body[campo].trim().length === 0) {
      errores.push(`El campo "${campo}" es obligatorio`);
    } else if (body[campo].trim().length > 100) {
      errores.push(`El campo "${campo}" no puede superar 100 caracteres`);
    }
  }

  if (body.telefono !== undefined && body.telefono !== null) {
    if (typeof body.telefono !== 'string') {
      errores.push('El campo "telefono" debe ser una cadena');
    } else if (body.telefono.trim().length > 20) {
      errores.push('El campo "telefono" no puede superar 20 caracteres');
    }
  }

  errores.push(...validarUbicacionDomicilio(body));
  if (Object.hasOwn(body, 'rol')) {
    errores.push('No está permitido modificar el rol de usuario');
  }

  return errores;
}

module.exports = {
  validarRegistro,
  validarLogin,
  validarActualizacionPerfil,
};
