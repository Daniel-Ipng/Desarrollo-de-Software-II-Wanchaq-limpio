USE ecorutas_wanchaq;

ALTER TABLE usuarios
  ADD COLUMN rol VARCHAR(20) NOT NULL DEFAULT 'ciudadano' AFTER password_hash;
