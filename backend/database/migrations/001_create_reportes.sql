USE ecorutas_wanchaq;

CREATE TABLE reportes (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ciudadano_id  BIGINT UNSIGNED NOT NULL,
  tipo          VARCHAR(50) NOT NULL,
  descripcion   TEXT NOT NULL,
  zona          VARCHAR(200) NOT NULL,
  estado        VARCHAR(20) NOT NULL DEFAULT 'pendiente',
  creado_en     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_ciudadano (ciudadano_id),
  INDEX idx_estado (estado),
  CONSTRAINT fk_reportes_usuario
    FOREIGN KEY (ciudadano_id) REFERENCES usuarios(id)
    ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;
