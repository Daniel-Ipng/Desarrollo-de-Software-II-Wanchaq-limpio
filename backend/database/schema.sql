-- ============================================================
-- ECORUTAS WANCHAQ
-- Esquema completo para MySQL + Node.js / Express + Flutter
--
-- ADVERTENCIA: este script elimina la base de datos existente
-- y todos sus datos. Ejecutar solo para empezar desde cero.
-- ============================================================

DROP DATABASE IF EXISTS ecorutas_wanchaq;

CREATE DATABASE ecorutas_wanchaq
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE ecorutas_wanchaq;

CREATE TABLE zonas (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255) DEFAULT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_zonas_nombre (nombre)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

CREATE TABLE usuarios (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) DEFAULT NULL,
    dni CHAR(8) DEFAULT NULL,
    correo VARCHAR(150) NOT NULL,
    telefono VARCHAR(20) DEFAULT NULL,
    password_hash VARCHAR(255) NOT NULL
        COMMENT 'Contraseña almacenada mediante hash bcrypt',
    rol VARCHAR(20) NOT NULL DEFAULT 'ciudadano',
    zona_id BIGINT UNSIGNED DEFAULT NULL,
    direccion VARCHAR(255) DEFAULT NULL,
    latitud_domicilio DECIMAL(10,7) DEFAULT NULL,
    longitud_domicilio DECIMAL(10,7) DEFAULT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_usuarios_correo (correo),
    UNIQUE KEY uq_usuarios_dni (dni),
    KEY idx_usuarios_rol (rol),
    KEY idx_usuarios_zona (zona_id),
    CONSTRAINT fk_usuarios_zona
        FOREIGN KEY (zona_id) REFERENCES zonas(id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_usuarios_rol
        CHECK (rol IN ('ciudadano', 'operador', 'admin', 'administrador')),
    CONSTRAINT chk_latitud_domicilio
        CHECK (latitud_domicilio IS NULL OR latitud_domicilio BETWEEN -90 AND 90),
    CONSTRAINT chk_longitud_domicilio
        CHECK (longitud_domicilio IS NULL OR longitud_domicilio BETWEEN -180 AND 180)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

CREATE TABLE reportes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    ciudadano_id BIGINT UNSIGNED NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    descripcion TEXT NOT NULL,
    zona VARCHAR(200) NOT NULL,
    latitud DECIMAL(10,7) DEFAULT NULL,
    longitud DECIMAL(10,7) DEFAULT NULL,
    imagen_url VARCHAR(500) DEFAULT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_reportes_ciudadano (ciudadano_id),
    KEY idx_reportes_estado (estado),
    KEY idx_reportes_fecha (creado_en),
    KEY idx_reportes_zona (zona),
    CONSTRAINT fk_reportes_usuario
        FOREIGN KEY (ciudadano_id) REFERENCES usuarios(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_reportes_estado
        CHECK (estado IN ('pendiente', 'enProceso', 'resuelto')),
    CONSTRAINT chk_reportes_latitud
        CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90),
    CONSTRAINT chk_reportes_longitud
        CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

CREATE TABLE rutas (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT DEFAULT NULL,
    zona_id BIGINT UNSIGNED DEFAULT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'programada',
    fecha_programada DATETIME DEFAULT NULL,
    fecha_inicio DATETIME DEFAULT NULL,
    fecha_finalizacion DATETIME DEFAULT NULL,
    creado_por BIGINT UNSIGNED DEFAULT NULL,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_rutas_zona (zona_id),
    KEY idx_rutas_estado (estado),
    CONSTRAINT fk_rutas_zona
        FOREIGN KEY (zona_id) REFERENCES zonas(id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_rutas_creador
        FOREIGN KEY (creado_por) REFERENCES usuarios(id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_rutas_estado
        CHECK (estado IN ('programada', 'en_progreso', 'finalizada', 'cancelada'))
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

CREATE TABLE asignaciones (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    ruta_id BIGINT UNSIGNED NOT NULL,
    operador_id BIGINT UNSIGNED NOT NULL,
    reporte_id BIGINT UNSIGNED NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'asignada',
    fecha_asignacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_atencion DATETIME DEFAULT NULL,
    observaciones TEXT DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_asignacion_ruta_reporte (ruta_id, reporte_id),
    KEY idx_asignaciones_operador (operador_id),
    KEY idx_asignaciones_reporte (reporte_id),
    KEY idx_asignaciones_estado (estado),
    CONSTRAINT fk_asignaciones_ruta
        FOREIGN KEY (ruta_id) REFERENCES rutas(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_asignaciones_operador
        FOREIGN KEY (operador_id) REFERENCES usuarios(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_asignaciones_reporte
        FOREIGN KEY (reporte_id) REFERENCES reportes(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_asignaciones_estado
        CHECK (estado IN ('asignada', 'en_progreso', 'completada', 'cancelada'))
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

INSERT INTO zonas (nombre, descripcion) VALUES
    ('Zona 1', 'Zona de servicio por definir'),
    ('Zona 2', 'Zona de servicio por definir'),
    ('Zona 3', 'Zona de servicio por definir'),
    ('Zona por confirmar', 'Para ciudadanos que necesitan confirmar su zona');
