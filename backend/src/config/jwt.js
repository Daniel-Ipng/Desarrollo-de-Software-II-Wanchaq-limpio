const crypto = require('crypto');

/**
 * Genera un token JWT simple firmado con HMAC-SHA256.
 *
 * Se implementa sin dependencias externas para mantener el proyecto ligero.
 * El token tiene una validez de 24 horas.
 *
 * @param {{ id: number, correo: string }} payload — datos del usuario
 * @returns {string} token JWT
 */
function generarToken(payload) {
  const secret = process.env.JWT_SECRET || 'dev_secret_inseguro';

  const header = { alg: 'HS256', typ: 'JWT' };
  const cuerpo = {
    ...payload,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24, // 24 horas
  };

  const b64Header = base64url(JSON.stringify(header));
  const b64Payload = base64url(JSON.stringify(cuerpo));
  const firma = crypto
    .createHmac('sha256', secret)
    .update(`${b64Header}.${b64Payload}`)
    .digest('base64url');

  return `${b64Header}.${b64Payload}.${firma}`;
}

/**
 * Verifica y decodifica un token JWT.
 *
 * @param {string} token — JWT completo
 * @returns {object|null} payload decodificado o null si es inválido/expirado
 */
function verificarToken(token) {
  const secret = process.env.JWT_SECRET || 'dev_secret_inseguro';

  const partes = token.split('.');
  if (partes.length !== 3) return null;

  const [b64Header, b64Payload, firmaRecibida] = partes;

  // Verificar firma
  const firmaEsperada = crypto
    .createHmac('sha256', secret)
    .update(`${b64Header}.${b64Payload}`)
    .digest('base64url');

  if (firmaRecibida !== firmaEsperada) return null;

  // Decodificar payload
  try {
    const payload = JSON.parse(Buffer.from(b64Payload, 'base64url').toString());

    // Verificar expiración
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
      return null;
    }

    return payload;
  } catch {
    return null;
  }
}

/**
 * Codifica una cadena en base64url (sin padding).
 */
function base64url(str) {
  return Buffer.from(str).toString('base64url');
}

module.exports = { generarToken, verificarToken };
