const { verificarToken } = require('../config/jwt');
const pool = require('../config/db');

/**
 * Middleware que verifica el token JWT en la cabecera Authorization.
 *
 * El token identifica al usuario; su rol se consulta en MySQL para no confiar
 * en datos de rol enviados por el cliente ni en permisos obsoletos del token.
 */
async function autenticar(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ mensaje: 'Token de autenticación requerido' });
  }

  const token = authHeader.split(' ')[1];
  const payload = verificarToken(token);

  if (!payload || payload.id == null) {
    return res.status(401).json({ mensaje: 'Token inválido o expirado' });
  }

  try {
    const [usuarios] = await pool.execute(
      'SELECT id, correo, rol FROM usuarios WHERE id = ? AND activo = 1 LIMIT 1',
      [payload.id]
    );

    if (usuarios.length === 0) {
      return res.status(401).json({ mensaje: 'Token inválido o expirado' });
    }

    const usuario = usuarios[0];
    req.usuario = {
      id: usuario.id,
      correo: usuario.correo,
      rol: usuario.rol,
    };
    return next();
  } catch (error) {
    console.error('Error al autenticar:', error.code || 'UNKNOWN');
    return res.status(500).json({ mensaje: 'Error interno del servidor' });
  }
}

module.exports = { autenticar };
