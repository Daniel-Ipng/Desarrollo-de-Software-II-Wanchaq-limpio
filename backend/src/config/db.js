const mysql = require('mysql2/promise');

/**
 * Pool de conexiones a MySQL.
 *
 * Las credenciales se leen de las variables de entorno definidas en .env.
 * Nunca se escriben contraseñas directamente en este archivo.
 */
const pool = mysql.createPool({
  host:     process.env.DB_HOST || 'localhost',
  port:     parseInt(process.env.DB_PORT || '3306', 10),
  user:     process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'ecorutas_wanchaq',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

module.exports = pool;
