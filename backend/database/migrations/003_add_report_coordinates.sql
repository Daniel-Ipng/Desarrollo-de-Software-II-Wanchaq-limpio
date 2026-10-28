USE ecorutas_wanchaq;

ALTER TABLE reportes
  ADD COLUMN latitud DECIMAL(10, 7) NULL AFTER zona,
  ADD COLUMN longitud DECIMAL(10, 7) NULL AFTER latitud;
