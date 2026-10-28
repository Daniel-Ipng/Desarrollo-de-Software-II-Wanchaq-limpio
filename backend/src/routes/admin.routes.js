const express = require('express');
const { obtenerPanel } = require('../controllers/admin.controller');
const { autenticar } = require('../middleware/auth.middleware');
const { autorizarRol } = require('../middleware/authorization.middleware');

const router = express.Router();

router.get(
  '/dashboard',
  autenticar,
  autorizarRol('admin', 'administrador'),
  obtenerPanel,
);

module.exports = router;
