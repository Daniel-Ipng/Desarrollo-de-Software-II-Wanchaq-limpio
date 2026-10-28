const express = require('express');
const { crear, listar, obtener } = require('../controllers/reportes.controller');
const { autenticar } = require('../middleware/auth.middleware');

const router = express.Router();

router.use(autenticar);
router.post('/', crear);
router.get('/', listar);
router.get('/:id', obtener);

module.exports = router;
