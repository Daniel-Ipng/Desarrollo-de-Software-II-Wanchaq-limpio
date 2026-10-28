const pool = require('../config/db');
const { validarCreacionReporte } = require('../validators/reportes.validator');

function serializarReporte(reporte) {
  return {
    id: Number(reporte.id),
    ciudadano_id: Number(reporte.ciudadano_id),
    tipo: reporte.tipo,
    descripcion: reporte.descripcion,
    zona: reporte.zona,
    latitud: reporte.latitud == null ? null : Number(reporte.latitud),
    longitud: reporte.longitud == null ? null : Number(reporte.longitud),
    imagen_url: reporte.imagen_url || null,
    estado: reporte.estado,
    creado_en: new Date(reporte.creado_en).toISOString(),
  };
}

function registrarError(operacion, error) {
  console.error(`Error al ${operacion} reporte:`, error.code || 'UNKNOWN');
}

async function crear(req, res) {
  const errores = validarCreacionReporte(req.body);
  if (errores.length > 0) {
    return res.status(400).json({ mensaje: errores[0], errores });
  }

  const { tipo, descripcion, zona, latitud, longitud } = req.body;

  try {
    const [resultado] = await pool.execute(
      `INSERT INTO reportes (ciudadano_id, tipo, descripcion, zona, latitud, longitud)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        req.usuario.id,
        tipo,
        descripcion.trim(),
        zona.trim(),
        latitud ?? null,
        longitud ?? null,
      ]
    );

    const [filas] = await pool.execute(
      `SELECT id, ciudadano_id, tipo, descripcion, zona, latitud, longitud,
              imagen_url, estado, creado_en
       FROM reportes WHERE id = ? AND ciudadano_id = ? LIMIT 1`,
      [resultado.insertId, req.usuario.id]
    );

    if (filas.length === 0) {
      return res.status(500).json({ mensaje: 'No se pudo recuperar el reporte creado' });
    }

    return res.status(201).json(serializarReporte(filas[0]));
  } catch (error) {
    registrarError('crear', error);
    return res.status(500).json({ mensaje: 'Error interno del servidor' });
  }
}

async function listar(req, res) {
  try {
    const [filas] = await pool.execute(
      `SELECT id, ciudadano_id, tipo, descripcion, zona, latitud, longitud,
              imagen_url, estado, creado_en
       FROM reportes WHERE ciudadano_id = ?
       ORDER BY creado_en DESC, id DESC`,
      [req.usuario.id]
    );

    return res.status(200).json(filas.map(serializarReporte));
  } catch (error) {
    registrarError('listar', error);
    return res.status(500).json({ mensaje: 'Error interno del servidor' });
  }
}

async function obtener(req, res) {
  const id = Number(req.params.id);
  if (!Number.isSafeInteger(id) || id <= 0) {
    return res.status(400).json({ mensaje: 'El identificador del reporte no es válido' });
  }

  try {
    const [filas] = await pool.execute(
      `SELECT id, ciudadano_id, tipo, descripcion, zona, latitud, longitud,
              imagen_url, estado, creado_en
       FROM reportes WHERE id = ? AND ciudadano_id = ? LIMIT 1`,
      [id, req.usuario.id]
    );

    if (filas.length === 0) {
      return res.status(404).json({ mensaje: 'Reporte no encontrado' });
    }

    return res.status(200).json(serializarReporte(filas[0]));
  } catch (error) {
    registrarError('obtener', error);
    return res.status(500).json({ mensaje: 'Error interno del servidor' });
  }
}

module.exports = { crear, listar, obtener };
