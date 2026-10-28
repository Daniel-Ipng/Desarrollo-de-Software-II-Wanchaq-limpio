const express = require('express');
const { registro, login, perfil, actualizarPerfil } = require('../controllers/auth.controller');
const { autenticar } = require('../middleware/auth.middleware');
const { autorizarRol } = require('../middleware/authorization.middleware');

const router = express.Router();

router.post('/registro', registro);
router.post('/login', login);
router.get('/perfil', autenticar, perfil);
router.put('/perfil', autenticar, autorizarRol('ciudadano'), actualizarPerfil);

module.exports = router;
