function obtenerPanel(req, res) {
  return res.status(200).json({
    usuario: {
      id: req.usuario.id,
      correo: req.usuario.correo,
      rol: req.usuario.rol,
    },
  });
}

module.exports = { obtenerPanel };
