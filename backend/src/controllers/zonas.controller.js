const pool = require('../config/db');

async function listarActivas(_req, res) {
  try {
    const [zonas] = await pool.execute(
      'SELECT id, nombre, descripcion FROM zonas WHERE activo = 1 ORDER BY nombre',
      []
    );

    return res.status(200).json(
      zonas.map((zona) => ({
        id: Number(zona.id),
        nombre: zona.nombre,
        descripcion: zona.descripcion,
      }))
    );
  } catch (error) {
    console.error('Error al listar zonas:', error.code || 'UNKNOWN');
    return res.status(500).json({ mensaje: 'No se pudieron cargar las zonas' });
  }
}

module.exports = { listarActivas };
