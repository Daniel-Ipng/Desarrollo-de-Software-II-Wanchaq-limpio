const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth.routes');
const reportesRoutes = require('./routes/reportes.routes');
const adminRoutes = require('./routes/admin.routes');
const zonasRoutes = require('./routes/zonas.routes');

const app = express();

// ─── Middlewares globales ─────────────────────────────────────────────────────

// CORS: permite peticiones desde Flutter Web en desarrollo (localhost)
app.use(cors({
  origin: '*', // En producción, restringir al dominio real
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Parseo de JSON en el body de las peticiones
app.use(express.json());

// ─── Rutas ────────────────────────────────────────────────────────────────────

app.use('/api/auth', authRoutes);
app.use('/api/reportes', reportesRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/zonas', zonasRoutes);

// Ruta de salud para verificar que el servidor está activo
app.get('/api/health', (_req, res) => {
  res.json({ estado: 'ok', mensaje: 'EcoRutas Wanchaq API activa' });
});

// ─── Manejo centralizado de errores ───────────────────────────────────────────

// Ruta no encontrada
app.use((_req, res) => {
  res.status(404).json({ mensaje: 'Recurso no encontrado' });
});

// Errores inesperados y cuerpos JSON malformados
app.use((err, _req, res, _next) => {
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ mensaje: 'El cuerpo JSON de la solicitud no es válido' });
  }

  console.error('Error no controlado:', err.code || err.type || 'UNKNOWN');
  res.status(500).json({ mensaje: 'Error interno del servidor' });
});

module.exports = app;
