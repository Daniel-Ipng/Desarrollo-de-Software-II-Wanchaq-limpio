const express = require('express');
const { listarActivas } = require('../controllers/zonas.controller');

const router = express.Router();

router.get('/', listarActivas);

module.exports = router;
