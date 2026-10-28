-- ECORUTAS WANCHAQ — Datos operativos de demostración
--
-- Ejecutar DESPUÉS de schema_supabase.sql en el SQL Editor de Supabase.
-- Este archivo es idempotente para las tablas que tienen identificadores
-- únicos. No crea usuarios de Auth ni contraseñas.
--
-- Para que aparezcan ciudadanos, operadores y administradores en el módulo
-- Usuarios, crea primero sus cuentas desde Supabase Auth y luego sus perfiles
-- con los datos proporcionados por el flujo de registro o por una Edge Function
-- segura. Nunca insertes UUIDs inventados en public.perfiles.

INSERT INTO public.zonas (
    nombre, descripcion, dias_recoleccion, hora_inicio, hora_fin,
    tipo_residuo_principal, contenedores, activo
)
VALUES
    ('Wanchaq Centro', 'Sector central del distrito', ARRAY[1, 3, 5]::SMALLINT[],
     '06:00', '10:00', 'Mixto', 18, TRUE),
    ('Ttio', 'Sector Ttio y calles colindantes', ARRAY[2, 4, 6]::SMALLINT[],
     '06:30', '10:30', 'Reciclable', 14, TRUE),
    ('Magisterio', 'Sector residencial Magisterio', ARRAY[1, 4]::SMALLINT[],
     '07:00', '11:00', 'Orgánico', 11, TRUE)
ON CONFLICT (nombre) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    dias_recoleccion = EXCLUDED.dias_recoleccion,
    hora_inicio = EXCLUDED.hora_inicio,
    hora_fin = EXCLUDED.hora_fin,
    tipo_residuo_principal = EXCLUDED.tipo_residuo_principal,
    contenedores = EXCLUDED.contenedores,
    activo = EXCLUDED.activo;

INSERT INTO public.tipos_residuo (
    nombre, descripcion, contenedor_recomendado, activo
)
VALUES
    ('Peligroso', 'Material que requiere manejo especializado', 'Contenedor rojo', TRUE),
    ('Voluminoso', 'Muebles, colchones y objetos de gran tamaño', 'Punto especial', TRUE)
ON CONFLICT (nombre) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    contenedor_recomendado = EXCLUDED.contenedor_recomendado,
    activo = EXCLUDED.activo;

INSERT INTO public.camiones (
    placa, modelo, capacidad_kg, zona_id, estado,
    combustible_porcentaje, latitud, longitud, ultima_ubicacion_en, activo
)
SELECT *
FROM (
    VALUES
      ('WCH-101', 'Compactador 2024', 8500.00,
       (SELECT id FROM public.zonas WHERE nombre = 'Wanchaq Centro'),
       'operativo', 78.00, -13.5264000, -71.9675000,
       NOW() - INTERVAL '12 minutes', TRUE),
      ('WCH-202', 'Compactador 2023', 7000.00,
       (SELECT id FROM public.zonas WHERE nombre = 'Ttio'),
       'operativo', 64.00, -13.5291000, -71.9721000,
       NOW() - INTERVAL '28 minutes', TRUE),
      ('WCH-303', 'Camión baranda 2022', 5000.00,
       (SELECT id FROM public.zonas WHERE nombre = 'Magisterio'),
       'mantenimiento', 35.00, NULL, NULL, NULL, TRUE)
) AS datos(
    placa, modelo, capacidad_kg, zona_id, estado, combustible_porcentaje,
    latitud, longitud, ultima_ubicacion_en, activo
)
WHERE datos.zona_id IS NOT NULL
ON CONFLICT (placa) DO UPDATE SET
    modelo = EXCLUDED.modelo,
    capacidad_kg = EXCLUDED.capacidad_kg,
    zona_id = EXCLUDED.zona_id,
    estado = EXCLUDED.estado,
    combustible_porcentaje = EXCLUDED.combustible_porcentaje,
    latitud = EXCLUDED.latitud,
    longitud = EXCLUDED.longitud,
    ultima_ubicacion_en = EXCLUDED.ultima_ubicacion_en,
    activo = EXCLUDED.activo;

INSERT INTO public.rutas (nombre, zona_id, turno, camion_id, puntos, activo)
SELECT
    datos.nombre,
    z.id,
    datos.turno,
    c.id,
    datos.puntos::jsonb,
    TRUE
FROM (
    VALUES
      ('Ruta Wanchaq Centro AM', 'Wanchaq Centro', 'manana', 'WCH-101',
       '[{"lat":-13.5264,"lng":-71.9675},{"lat":-13.5272,"lng":-71.9658}]'),
      ('Ruta Ttio PM', 'Ttio', 'tarde', 'WCH-202',
       '[{"lat":-13.5291,"lng":-71.9721},{"lat":-13.5310,"lng":-71.9740}]'),
      ('Ruta Magisterio AM', 'Magisterio', 'manana', 'WCH-303',
       '[{"lat":-13.5228,"lng":-71.9589},{"lat":-13.5240,"lng":-71.9605}]')
) AS datos(nombre, zona, turno, placa, puntos)
JOIN public.zonas z ON z.nombre = datos.zona
LEFT JOIN public.camiones c ON c.placa = datos.placa
WHERE NOT EXISTS (
    SELECT 1 FROM public.rutas r WHERE r.nombre = datos.nombre
);

INSERT INTO public.horarios_recoleccion (
    zona_id, dia_semana, hora_inicio, hora_fin, tipo_residuo, activo
)
SELECT z.id, datos.dia, datos.inicio::TIME, datos.fin::TIME,
       datos.tipo, TRUE
FROM (
    VALUES
      ('Wanchaq Centro', 1, '06:00', '10:00', 'Mixto'),
      ('Wanchaq Centro', 3, '06:00', '10:00', 'Mixto'),
      ('Wanchaq Centro', 5, '06:00', '10:00', 'Mixto'),
      ('Ttio', 2, '06:30', '10:30', 'Reciclable'),
      ('Ttio', 4, '06:30', '10:30', 'Reciclable'),
      ('Ttio', 6, '06:30', '10:30', 'Reciclable'),
      ('Magisterio', 1, '07:00', '11:00', 'Orgánico'),
      ('Magisterio', 4, '07:00', '11:00', 'Orgánico')
) AS datos(zona, dia, inicio, fin, tipo)
JOIN public.zonas z ON z.nombre = datos.zona
WHERE NOT EXISTS (
    SELECT 1
    FROM public.horarios_recoleccion h
    WHERE h.zona_id = z.id
      AND h.dia_semana = datos.dia
      AND h.hora_inicio = datos.inicio::TIME
);

INSERT INTO public.recolecciones (
    zona_id, ruta_id, camion_id, tipo_residuo, cantidad_kg,
    recolectado_en, observaciones, estado
)
SELECT
    z.id,
    r.id,
    c.id,
    datos.tipo,
    datos.cantidad,
    NOW() - datos.dias_anteriores * INTERVAL '1 day',
    datos.observaciones,
    'registrada'
FROM (
    VALUES
      ('Wanchaq Centro', 'Ruta Wanchaq Centro AM', 'WCH-101', 'Mixto', 1240.50, 1,
       'Servicio completado sin incidencias'),
      ('Ttio', 'Ruta Ttio PM', 'WCH-202', 'Reciclable', 830.00, 2,
       'Se recuperaron materiales reciclables'),
      ('Magisterio', 'Ruta Magisterio AM', 'WCH-303', 'Orgánico', 615.75, 4,
       'Registro de prueba operativa')
) AS datos(zona, ruta, placa, tipo, cantidad, dias_anteriores, observaciones)
JOIN public.zonas z ON z.nombre = datos.zona
LEFT JOIN public.rutas r ON r.nombre = datos.ruta
LEFT JOIN public.camiones c ON c.placa = datos.placa
WHERE NOT EXISTS (
    SELECT 1
    FROM public.recolecciones x
    WHERE x.zona_id = z.id
      AND x.observaciones = datos.observaciones
);

-- Reportes ciudadanos: se insertan solo para perfiles Auth existentes.
-- Se crean tres incidencias por cada ciudadano activo para que el panel,
-- "Mis reportes" y el mapa tengan datos visibles sin inventar usuarios.
INSERT INTO public.reportes (
    ciudadano_id, tipo, descripcion, zona, latitud, longitud, estado
)
SELECT
    p.id,
    datos.tipo,
    datos.descripcion || ' - reporte demo ' || p.dni,
    datos.zona,
    datos.latitud,
    datos.longitud,
    datos.estado
FROM (
    VALUES
      ('residuosAcumulados', 'Acumulación de residuos junto al parque principal',
       'Wanchaq Centro', -13.5264, -71.9675, 'pendiente'),
      ('contenedorLleno', 'Contenedor lleno y requiere recojo',
       'Ttio', -13.5291, -71.9721, 'enProceso'),
      ('faltaRecoleccion', 'No se realizó la recolección programada',
       'Magisterio', -13.5228, -71.9589, 'resuelto')
) AS datos(tipo, descripcion, zona, latitud, longitud, estado)
JOIN public.perfiles p
  ON p.rol = 'ciudadano'
 AND p.activo = TRUE
WHERE NOT EXISTS (
    SELECT 1
    FROM public.reportes r
    WHERE r.ciudadano_id = p.id
      AND r.descripcion = datos.descripcion || ' - reporte demo ' || p.dni
);

-- Notificaciones para perfiles existentes, sin duplicarlas.
INSERT INTO public.notificaciones (usuario_id, titulo, mensaje, tipo)
SELECT p.id, 'Datos operativos disponibles',
       'Ya puedes consultar horarios y seguimiento de camiones.',
       'sistema'
FROM public.perfiles p
WHERE p.activo = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.usuario_id = p.id
        AND n.titulo = 'Datos operativos disponibles'
  );

INSERT INTO public.actividad_ecologica (usuario_id, puntos, motivo)
SELECT p.id, 25, 'Participación inicial en EcoRutas'
FROM public.perfiles p
WHERE p.rol = 'ciudadano'
  AND p.activo = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM public.actividad_ecologica a
      WHERE a.usuario_id = p.id
        AND a.motivo = 'Participación inicial en EcoRutas'
  );

-- Comprobación rápida para el SQL Editor.
SELECT 'zonas' AS tabla, COUNT(*) AS registros FROM public.zonas
UNION ALL
SELECT 'camiones', COUNT(*) FROM public.camiones
UNION ALL
SELECT 'rutas', COUNT(*) FROM public.rutas
UNION ALL
SELECT 'horarios_recoleccion', COUNT(*) FROM public.horarios_recoleccion
UNION ALL
SELECT 'recolecciones', COUNT(*) FROM public.recolecciones
UNION ALL
SELECT 'perfiles', COUNT(*) FROM public.perfiles
UNION ALL
SELECT 'reportes', COUNT(*) FROM public.reportes
UNION ALL
SELECT 'notificaciones', COUNT(*) FROM public.notificaciones;
