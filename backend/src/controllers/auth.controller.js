const bcrypt = require('bcrypt');
const pool = require('../config/db');
const { generarToken } = require('../config/jwt');
const {
  validarRegistro,
  validarLogin,
  validarActualizacionPerfil,
} = require('../validators/auth.validator');

// Número de rondas de salt para bcrypt
const SALT_ROUNDS = 10;

/**
 * POST /api/auth/registro
 *
 * Registra un nuevo ciudadano. Valida los campos, comprueba que el correo
 * y el DNI no estén registrados, hashea la contraseña con bcrypt y guarda
 * el usuario en MySQL.
 */
async function registro(req, res) {
  try {
    // 1. Validar campos
    const errores = validarRegistro(req.body);
    if (errores.length > 0) {
      return res.status(400).json({ mensaje: errores[0], errores });
    }

    const {
      nombres,
      apellidos,
      dni,
      correo,
      telefono,
      contrasena,
      zona_id,
      direccion,
      latitud_domicilio,
      longitud_domicilio,
    } = req.body;

    const [zonas] = await pool.execute(
      'SELECT id, nombre FROM zonas WHERE id = ? AND activo = 1 LIMIT 1',
      [zona_id]
    );
    if (zonas.length === 0) {
      return res.status(400).json({ mensaje: 'La zona seleccionada no está disponible' });
    }

    // 2. Comprobar correo duplicado
    const [existentes] = await pool.execute(
      'SELECT id FROM usuarios WHERE correo = ? OR dni = ? LIMIT 1',
      [correo.trim(), dni.trim()]
    );

    if (existentes.length > 0) {
      return res.status(409).json({
        mensaje: 'Ya existe una cuenta con ese correo o DNI',
      });
    }

    // 3. Hashear contraseña con bcrypt (nunca texto plano)
    const hash = await bcrypt.hash(contrasena, SALT_ROUNDS);

    // 4. Insertar en la base de datos con consulta parametrizada
    const [resultado] = await pool.execute(
      `INSERT INTO usuarios (
         nombre, apellidos, dni, correo, telefono, password_hash, rol,
         zona_id, direccion, latitud_domicilio, longitud_domicilio
       ) VALUES (?, ?, ?, ?, ?, ?, 'ciudadano', ?, ?, ?, ?)`,
      [
        nombres.trim(),
        apellidos.trim(),
        dni.trim(),
        correo.trim(),
        telefono ? telefono.trim() : null,
        hash,
        zona_id,
        direccion.trim(),
        latitud_domicilio ?? null,
        longitud_domicilio ?? null,
      ]
    );

    const usuarioId = resultado.insertId;

    // 5. Generar token JWT
    const token = generarToken({ id: usuarioId, correo: correo.trim() });

    // 6. Responder con el usuario (sin la contraseña) y el token
    return res.status(201).json({
      token,
      usuario: {
        id: usuarioId,
        nombres: nombres.trim(),
        apellidos: apellidos.trim(),
        dni: dni.trim(),
        correo: correo.trim(),
        telefono: telefono ? telefono.trim() : null,
        rol: 'ciudadano',
        zona_id,
        zona_nombre: zonas[0].nombre,
        direccion: direccion.trim(),
        latitud_domicilio: latitud_domicilio ?? null,
        longitud_domicilio: longitud_domicilio ?? null,
      },
    });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        mensaje: 'Ya existe una cuenta con ese correo o DNI',
      });
    }

    console.error('Error en registro:', error.code || 'UNKNOWN');
    return res.status(500).json({ mensaje: 'Error interno del servidor' });
  }
}

/**
 * POST /api/auth/login
 *
 * Inicia sesión verificando correo y contraseña contra la base de datos.
 */
async function login(req, res) {
  try {
    const errores = validarLogin(req.body);
    if (errores.length > 0) {
      return res.status(400).json({ mensaje: errores[0], errores });
    }

    const { correo, contrasena } = req.body;

    // Buscar usuario por correo
    const [usuarios] = await pool.execute(
      `SELECT u.id, u.nombre AS nombres, u.apellidos, u.dni, u.correo,
              u.telefono, u.password_hash, u.rol, u.zona_id, z.nombre AS zona_nombre,
              u.direccion, u.latitud_domicilio, u.longitud_domicilio
       FROM usuarios u
       LEFT JOIN zonas z ON z.id = u.zona_id
       WHERE u.correo = ? AND u.activo = 1 LIMIT 1`,
      [correo.trim()]
    );

    if (usuarios.length === 0) {
      return res.status(401).json({ mensaje: 'Correo o contraseña incorrectos' });
    }

    const usuario = usuarios[0];

    // Comparar contraseña con el hash almacenado
    const contrasenaValida = await bcrypt.compare(contrasena, usuario.password_hash);
    if (!contrasenaValida) {
      return res.status(401).json({ mensaje: 'Correo o contraseña incorrectos' });
    }

    // Generar token
    const token = generarToken({ id: usuario.id, correo: usuario.correo });

    return res.status(200).json({
      token,
      usuario: {
        id: usuario.id,
        nombres: usuario.nombres,
        apellidos: usuario.apellidos,
        dni: usuario.dni,
        correo: usuario.correo,
        telefono: usuario.telefono,
        rol: usuario.rol,
        zona_id: usuario.zona_id,
        zona_nombre: usuario.zona_nombre,
        direccion: usuario.direccion,
        latitud_domicilio: usuario.latitud_domicilio,
        longitud_domicilio: usuario.longitud_domicilio,
      },
    });
  } catch (error) {
    console.error('Error en login:', error.code || 'UNKNOWN');
    return res.status(500).json({ mensaje: 'Error interno del servidor' });
  }
}

/**
 * GET /api/auth/perfil
 *
 * Devuelve los datos del usuario autenticado (requiere token JWT).
 */
async function perfil(req, res) {
  try {
    const [usuarios] = await pool.execute(
      `SELECT u.id, u.nombre AS nombres, u.apellidos, u.dni, u.correo,
              u.telefono, u.rol, u.zona_id, z.nombre AS zona_nombre,
              u.direccion, u.latitud_domicilio, u.longitud_domicilio
       FROM usuarios u
       LEFT JOIN zonas z ON z.id = u.zona_id
       WHERE u.id = ? AND u.activo = 1 LIMIT 1`,
      [req.usuario.id]
    );

    if (usuarios.length === 0) {
      return res.status(404).json({ mensaje: 'Usuario no encontrado' });
    }

    return res.status(200).json(usuarios[0]);
  } catch (error) {
    console.error('Error en perfil:', error.code || 'UNKNOWN');
    return res.status(500).json({ mensaje: 'Error interno del servidor' });
  }
}

async function actualizarPerfil(req, res) {
  const errores = validarActualizacionPerfil(req.body);
  if (errores.length > 0) {
    return res.status(400).json({ mensaje: errores[0], errores });
  }

  const {
    nombre,
    apellidos,
    telefono,
    zona_id,
    direccion,
    latitud_domicilio,
    longitud_domicilio,
  } = req.body;

  try {
    const [zonas] = await pool.execute(
      'SELECT id FROM zonas WHERE id = ? AND activo = 1 LIMIT 1',
      [zona_id]
    );
    if (zonas.length === 0) {
      return res.status(400).json({ mensaje: 'La zona seleccionada no está disponible' });
    }

    await pool.execute(
      `UPDATE usuarios
       SET nombre = ?, apellidos = ?, telefono = ?, zona_id = ?, direccion = ?,
           latitud_domicilio = ?, longitud_domicilio = ?,
           fecha_actualizacion = CURRENT_TIMESTAMP
       WHERE id = ? AND activo = 1`,
      [
        nombre.trim(),
        apellidos.trim(),
        typeof telefono === 'string' && telefono.trim() ? telefono.trim() : null,
        zona_id,
        direccion.trim(),
        latitud_domicilio ?? null,
        longitud_domicilio ?? null,
        req.usuario.id,
      ]
    );

    return perfil(req, res);
  } catch (error) {
    console.error('Error al actualizar perfil:', error.code || 'UNKNOWN');
    return res.status(500).json({ mensaje: 'No se pudo actualizar el perfil' });
  }
}

module.exports = { registro, login, perfil, actualizarPerfil };
