-- ============================================================
-- ECORUTAS WANCHAQ — Esquema para Supabase (PostgreSQL)
--
-- Ejecutar en el SQL Editor de tu proyecto Supabase.
-- Supabase maneja la autenticación en auth.users automáticamente.
-- Esta tabla almacena el perfil complementario del usuario.
-- ============================================================

-- ─── Extensión para UUID ──────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── Tabla: zonas ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.zonas (
    id          BIGSERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255),
    activo      BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_zonas_nombre UNIQUE (nombre)
);

-- ─── Tabla: perfiles ──────────────────────────────────────────────────────────
-- Extiende auth.users de Supabase con datos específicos de la app.
-- La columna `id` referencia al UUID de auth.users.
CREATE TABLE IF NOT EXISTS public.perfiles (
    id                 UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombres            VARCHAR(100) NOT NULL,
    apellidos          VARCHAR(100),
    dni                CHAR(8),
    correo             VARCHAR(150) NOT NULL,
    telefono           VARCHAR(20),
    rol                VARCHAR(20) NOT NULL DEFAULT 'ciudadano',
    zona_id            BIGINT REFERENCES public.zonas(id) ON UPDATE CASCADE ON DELETE SET NULL,
    direccion          VARCHAR(500),
    latitud_domicilio  DECIMAL(10,7),
    longitud_domicilio DECIMAL(10,7),
    activo             BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_perfiles_dni    UNIQUE (dni),
    CONSTRAINT uq_perfiles_correo UNIQUE (correo),
    CONSTRAINT chk_perfiles_rol   CHECK (rol IN ('ciudadano', 'operador', 'admin', 'administrador')),
    CONSTRAINT chk_lat_domicilio  CHECK (latitud_domicilio  IS NULL OR latitud_domicilio  BETWEEN -90  AND 90),
    CONSTRAINT chk_lng_domicilio  CHECK (longitud_domicilio IS NULL OR longitud_domicilio BETWEEN -180 AND 180)
);

-- Trigger para actualizar fecha_actualizacion automáticamente
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.fecha_actualizacion = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_perfiles_updated_at
    BEFORE UPDATE ON public.perfiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ─── Tabla: reportes ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reportes (
    id           BIGSERIAL PRIMARY KEY,
    ciudadano_id UUID NOT NULL REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    tipo         VARCHAR(50) NOT NULL,
    descripcion  TEXT NOT NULL,
    zona         VARCHAR(200) NOT NULL,
    latitud      DECIMAL(10,7),
    longitud     DECIMAL(10,7),
    imagen_url   VARCHAR(500),
    estado       VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    creado_en    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_reportes_estado   CHECK (estado IN ('pendiente', 'enProceso', 'resuelto')),
    CONSTRAINT chk_reportes_latitud  CHECK (latitud  IS NULL OR latitud  BETWEEN -90  AND 90),
    CONSTRAINT chk_reportes_longitud CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180)
);

CREATE INDEX IF NOT EXISTS idx_reportes_ciudadano ON public.reportes (ciudadano_id);
CREATE INDEX IF NOT EXISTS idx_reportes_estado    ON public.reportes (estado);
CREATE INDEX IF NOT EXISTS idx_reportes_fecha     ON public.reportes (creado_en DESC);

CREATE OR REPLACE TRIGGER trg_reportes_updated_at
    BEFORE UPDATE ON public.reportes
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Función SECURITY DEFINER para que las políticas administrativas no
-- vuelvan a evaluar la política RLS de `perfiles` de forma recursiva.
CREATE OR REPLACE FUNCTION public.es_administrador()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.perfiles
        WHERE id = auth.uid()
          AND rol IN ('admin', 'administrador')
          AND activo = TRUE
    );
$$;

REVOKE ALL ON FUNCTION public.es_administrador() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.es_administrador() TO authenticated;

-- ─── Datos iniciales: zonas ───────────────────────────────────────────────────
INSERT INTO public.zonas (nombre, descripcion) VALUES
    ('Zona 1', 'Zona de servicio por definir'),
    ('Zona 2', 'Zona de servicio por definir'),
    ('Zona 3', 'Zona de servicio por definir'),
    ('Zona por confirmar', 'Para ciudadanos que necesitan confirmar su zona')
ON CONFLICT (nombre) DO NOTHING;

-- ─── Row Level Security (RLS) ─────────────────────────────────────────────────
-- Activa RLS para proteger los datos de cada usuario.

ALTER TABLE public.zonas    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reportes ENABLE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON public.zonas TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.perfiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.reportes TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

DROP POLICY IF EXISTS "zonas_lectura_publica" ON public.zonas;
DROP POLICY IF EXISTS "perfiles_select_propio" ON public.perfiles;
DROP POLICY IF EXISTS "perfiles_insert_propio" ON public.perfiles;
DROP POLICY IF EXISTS "perfiles_update_propio" ON public.perfiles;
DROP POLICY IF EXISTS "reportes_select_propio" ON public.reportes;
DROP POLICY IF EXISTS "reportes_insert_propio" ON public.reportes;
DROP POLICY IF EXISTS "reportes_select_admin" ON public.reportes;
DROP POLICY IF EXISTS "reportes_update_admin" ON public.reportes;
DROP POLICY IF EXISTS "perfiles_select_admin" ON public.perfiles;
DROP POLICY IF EXISTS "perfiles_update_admin" ON public.perfiles;
DROP POLICY IF EXISTS "zonas_gestion_admin" ON public.zonas;
DROP POLICY IF EXISTS "reportes_storage_insert_propio" ON storage.objects;
DROP POLICY IF EXISTS "reportes_storage_update_propio" ON storage.objects;
DROP POLICY IF EXISTS "reportes_storage_delete_propio" ON storage.objects;

-- Zonas: el registro se hace sin sesión, así que `anon` también debe poder leer.
CREATE POLICY "zonas_lectura_publica" ON public.zonas
    FOR SELECT TO anon, authenticated
    USING (activo = TRUE);

-- Perfiles: cada usuario solo puede ver y editar su propio perfil
CREATE POLICY "perfiles_select_propio" ON public.perfiles
    FOR SELECT TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "perfiles_insert_propio" ON public.perfiles
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = id);

CREATE POLICY "perfiles_update_propio" ON public.perfiles
    FOR UPDATE TO authenticated
    USING (auth.uid() = id);

-- Reportes: cada ciudadano puede crear y ver sus propios reportes
CREATE POLICY "reportes_select_propio" ON public.reportes
    FOR SELECT TO authenticated
    USING (auth.uid() = ciudadano_id);

CREATE POLICY "reportes_insert_propio" ON public.reportes
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = ciudadano_id);

-- Administradores pueden ver todos los reportes y perfiles
CREATE POLICY "reportes_select_admin" ON public.reportes
    FOR SELECT TO authenticated
    USING (public.es_administrador());

CREATE POLICY "reportes_update_admin" ON public.reportes
    FOR UPDATE TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

CREATE POLICY "perfiles_select_admin" ON public.perfiles
    FOR SELECT TO authenticated
    USING (public.es_administrador());

CREATE POLICY "perfiles_update_admin" ON public.perfiles
    FOR UPDATE TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

CREATE POLICY "zonas_gestion_admin" ON public.zonas
    FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

-- Crea el bucket público para que los enlaces de imágenes sean visibles.
INSERT INTO storage.buckets (id, name, public)
VALUES ('reportes', 'reportes', TRUE)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;
CREATE POLICY "reportes_storage_insert_propio" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'reportes'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "reportes_storage_update_propio" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'reportes'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "reportes_storage_delete_propio" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'reportes'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );


-- ============================================================

-- ─── Campos operativos de zonas ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_operational_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.actualizado_en = NOW();
    RETURN NEW;
END;
$$;

ALTER TABLE public.zonas
    ADD COLUMN IF NOT EXISTS dias_recoleccion SMALLINT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS hora_inicio TIME,
    ADD COLUMN IF NOT EXISTS hora_fin TIME,
    ADD COLUMN IF NOT EXISTS tipo_residuo_principal VARCHAR(50),
    ADD COLUMN IF NOT EXISTS contenedores INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS geometria JSONB;

ALTER TABLE public.zonas
    DROP CONSTRAINT IF EXISTS chk_zonas_dias_recoleccion;
ALTER TABLE public.zonas
    ADD CONSTRAINT chk_zonas_dias_recoleccion
    CHECK (dias_recoleccion <@ ARRAY[0, 1, 2, 3, 4, 5, 6]::SMALLINT[]);

ALTER TABLE public.zonas
    DROP CONSTRAINT IF EXISTS chk_zonas_horario;
ALTER TABLE public.zonas
    ADD CONSTRAINT chk_zonas_horario
    CHECK (hora_fin IS NULL OR hora_inicio IS NULL OR hora_fin > hora_inicio);

ALTER TABLE public.zonas
    DROP CONSTRAINT IF EXISTS chk_zonas_contenedores;
ALTER TABLE public.zonas
    ADD CONSTRAINT chk_zonas_contenedores CHECK (contenedores >= 0);

-- ─── Camiones y ubicación GPS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.camiones (
    id                    BIGSERIAL PRIMARY KEY,
    placa                 VARCHAR(12) NOT NULL,
    modelo                VARCHAR(100),
    capacidad_kg          NUMERIC(10,2),
    zona_id               BIGINT REFERENCES public.zonas(id) ON DELETE SET NULL,
    operador_id           UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    estado                VARCHAR(20) NOT NULL DEFAULT 'operativo',
    combustible_porcentaje NUMERIC(5,2),
    latitud               DECIMAL(10,7),
    longitud              DECIMAL(10,7),
    ultima_ubicacion_en   TIMESTAMPTZ,
    activo                BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_camiones_placa UNIQUE (placa),
    CONSTRAINT chk_camiones_estado
        CHECK (estado IN ('operativo', 'mantenimiento', 'fuera_servicio')),
    CONSTRAINT chk_camiones_capacidad CHECK (capacidad_kg IS NULL OR capacidad_kg > 0),
    CONSTRAINT chk_camiones_combustible
        CHECK (combustible_porcentaje IS NULL OR combustible_porcentaje BETWEEN 0 AND 100),
    CONSTRAINT chk_camiones_latitud
        CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90),
    CONSTRAINT chk_camiones_longitud
        CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180)
);

CREATE INDEX IF NOT EXISTS idx_camiones_zona ON public.camiones (zona_id);
CREATE INDEX IF NOT EXISTS idx_camiones_estado ON public.camiones (estado);
CREATE OR REPLACE TRIGGER trg_camiones_updated_at
    BEFORE UPDATE ON public.camiones
    FOR EACH ROW EXECUTE FUNCTION public.handle_operational_updated_at();

-- ─── Rutas y puntos de recolección ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rutas (
    id             BIGSERIAL PRIMARY KEY,
    nombre         VARCHAR(120) NOT NULL,
    zona_id        BIGINT NOT NULL REFERENCES public.zonas(id) ON DELETE RESTRICT,
    turno          VARCHAR(20) NOT NULL DEFAULT 'manana',
    camion_id      BIGINT REFERENCES public.camiones(id) ON DELETE SET NULL,
    operador_id    UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    puntos         JSONB NOT NULL DEFAULT '[]'::JSONB,
    activo         BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_rutas_turno CHECK (turno IN ('manana', 'tarde', 'noche'))
);

CREATE INDEX IF NOT EXISTS idx_rutas_zona ON public.rutas (zona_id);
CREATE INDEX IF NOT EXISTS idx_rutas_camion ON public.rutas (camion_id);
CREATE OR REPLACE TRIGGER trg_rutas_updated_at
    BEFORE UPDATE ON public.rutas
    FOR EACH ROW EXECUTE FUNCTION public.handle_operational_updated_at();

-- ─── Horarios configurables de recolección ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.horarios_recoleccion (
    id             BIGSERIAL PRIMARY KEY,
    zona_id        BIGINT NOT NULL REFERENCES public.zonas(id) ON DELETE CASCADE,
    dia_semana     SMALLINT NOT NULL,
    hora_inicio    TIME NOT NULL,
    hora_fin       TIME NOT NULL,
    tipo_residuo   VARCHAR(50) NOT NULL DEFAULT 'mixto',
    activo         BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_horarios_dia CHECK (dia_semana BETWEEN 0 AND 6),
    CONSTRAINT chk_horarios_hora CHECK (hora_fin > hora_inicio)
);

CREATE INDEX IF NOT EXISTS idx_horarios_zona_dia
    ON public.horarios_recoleccion (zona_id, dia_semana);
CREATE OR REPLACE TRIGGER trg_horarios_updated_at
    BEFORE UPDATE ON public.horarios_recoleccion
    FOR EACH ROW EXECUTE FUNCTION public.handle_operational_updated_at();

-- ─── Catálogo de residuos ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tipos_residuo (
    id                   BIGSERIAL PRIMARY KEY,
    nombre               VARCHAR(80) NOT NULL,
    descripcion          VARCHAR(255),
    contenedor_recomendado VARCHAR(80),
    activo               BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_tipos_residuo_nombre UNIQUE (nombre)
);

INSERT INTO public.tipos_residuo (nombre, descripcion, contenedor_recomendado)
VALUES
    ('Mixto', 'Residuos no separados', 'Contenedor general'),
    ('Orgánico', 'Residuos biodegradables', 'Contenedor marrón'),
    ('Reciclable', 'Material recuperable', 'Contenedor de reciclaje')
ON CONFLICT (nombre) DO NOTHING;

-- ─── Recolecciones operativas ────────────────────────────────────────────────
-- ciudadano_id es opcional: solo se rellena cuando existe una relación
-- individual real. Una recolección de zona no se atribuye automáticamente
-- a todos sus ciudadanos.
CREATE TABLE IF NOT EXISTS public.recolecciones (
    id                 BIGSERIAL PRIMARY KEY,
    zona_id            BIGINT NOT NULL REFERENCES public.zonas(id) ON DELETE RESTRICT,
    ruta_id            BIGINT REFERENCES public.rutas(id) ON DELETE SET NULL,
    camion_id          BIGINT REFERENCES public.camiones(id) ON DELETE SET NULL,
    operador_id        UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    ciudadano_id       UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    tipo_residuo       VARCHAR(50) NOT NULL,
    cantidad_kg        NUMERIC(10,2),
    recolectado_en     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    observaciones      TEXT,
    estado             VARCHAR(20) NOT NULL DEFAULT 'registrada',
    creado_en          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_recolecciones_cantidad
        CHECK (cantidad_kg IS NULL OR cantidad_kg >= 0),
    CONSTRAINT chk_recolecciones_estado
        CHECK (estado IN ('programada', 'en_curso', 'registrada', 'cancelada'))
);

CREATE INDEX IF NOT EXISTS idx_recolecciones_zona_fecha
    ON public.recolecciones (zona_id, recolectado_en DESC);
CREATE INDEX IF NOT EXISTS idx_recolecciones_ciudadano
    ON public.recolecciones (ciudadano_id, recolectado_en DESC);

-- ─── Notificaciones personales ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notificaciones (
    id          BIGSERIAL PRIMARY KEY,
    usuario_id  UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
    titulo      VARCHAR(150) NOT NULL,
    mensaje     TEXT NOT NULL,
    tipo        VARCHAR(30) NOT NULL DEFAULT 'general',
    leida       BOOLEAN NOT NULL DEFAULT FALSE,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    leida_en    TIMESTAMPTZ,
    CONSTRAINT chk_notificaciones_tipo
        CHECK (tipo IN ('general', 'reporte', 'recoleccion', 'sistema'))
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario
    ON public.notificaciones (usuario_id, leida, creado_en DESC);

-- ─── Niveles y actividad ecológica ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.niveles_ecologicos (
    id             SMALLSERIAL PRIMARY KEY,
    nombre         VARCHAR(30) NOT NULL,
    puntos_minimos INTEGER NOT NULL,
    puntos_maximos INTEGER,
    orden          SMALLINT NOT NULL,
    CONSTRAINT uq_niveles_ecologicos_nombre UNIQUE (nombre),
    CONSTRAINT uq_niveles_ecologicos_orden UNIQUE (orden),
    CONSTRAINT chk_niveles_puntos CHECK (
        puntos_minimos >= 0
        AND (puntos_maximos IS NULL OR puntos_maximos >= puntos_minimos)
    )
);

INSERT INTO public.niveles_ecologicos
    (nombre, puntos_minimos, puntos_maximos, orden)
VALUES
    ('Eco Semilla', 0, 99, 1),
    ('Eco Bronce', 100, 249, 2),
    ('Eco Plata', 250, 499, 3),
    ('Eco Oro', 500, 999, 4),
    ('Eco Platino', 1000, NULL, 5)
ON CONFLICT (nombre) DO UPDATE SET
    puntos_minimos = EXCLUDED.puntos_minimos,
    puntos_maximos = EXCLUDED.puntos_maximos,
    orden = EXCLUDED.orden;

CREATE TABLE IF NOT EXISTS public.actividad_ecologica (
    id          BIGSERIAL PRIMARY KEY,
    usuario_id  UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
    puntos      INTEGER NOT NULL,
    motivo      VARCHAR(120) NOT NULL,
    reporte_id  BIGINT REFERENCES public.reportes(id) ON DELETE SET NULL,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_actividad_puntos CHECK (puntos > 0)
);

-- Auditoría mínima de operaciones administrativas. Nunca almacena credenciales
-- ni tokens; solo identifica la entidad y los valores de negocio modificados.
CREATE TABLE IF NOT EXISTS public.auditoria (
    id BIGSERIAL PRIMARY KEY,
    actor_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
    entidad VARCHAR(80) NOT NULL,
    operacion VARCHAR(20) NOT NULL,
    registro_id TEXT,
    valores_anteriores JSONB,
    valores_nuevos JSONB,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auditoria_fecha
    ON public.auditoria (creado_en DESC);

CREATE OR REPLACE FUNCTION public.registrar_auditoria()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    anterior JSONB;
    nuevo JSONB;
    id_registro TEXT;
BEGIN
    anterior := CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END;
    nuevo := CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END;
    id_registro := COALESCE(nuevo->>'id', anterior->>'id');
    INSERT INTO public.auditoria (
        actor_id, entidad, operacion, registro_id,
        valores_anteriores, valores_nuevos
    )
    VALUES (
        auth.uid(), TG_TABLE_NAME, TG_OP, id_registro, anterior, nuevo
    );
    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_auditoria_perfiles ON public.perfiles;
CREATE TRIGGER trg_auditoria_perfiles
    AFTER INSERT OR UPDATE OR DELETE ON public.perfiles
    FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();
DROP TRIGGER IF EXISTS trg_auditoria_camiones ON public.camiones;
CREATE TRIGGER trg_auditoria_camiones
    AFTER INSERT OR UPDATE OR DELETE ON public.camiones
    FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();
DROP TRIGGER IF EXISTS trg_auditoria_rutas ON public.rutas;
CREATE TRIGGER trg_auditoria_rutas
    AFTER INSERT OR UPDATE OR DELETE ON public.rutas
    FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();
DROP TRIGGER IF EXISTS trg_auditoria_zonas ON public.zonas;
CREATE TRIGGER trg_auditoria_zonas
    AFTER INSERT OR UPDATE OR DELETE ON public.zonas
    FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();
DROP TRIGGER IF EXISTS trg_auditoria_reportes ON public.reportes;
CREATE TRIGGER trg_auditoria_reportes
    AFTER INSERT OR UPDATE OR DELETE ON public.reportes
    FOR EACH ROW EXECUTE FUNCTION public.registrar_auditoria();

CREATE INDEX IF NOT EXISTS idx_actividad_ecologica_usuario
    ON public.actividad_ecologica (usuario_id, creado_en DESC);

CREATE OR REPLACE VIEW public.resumen_ecologico AS
SELECT
    p.id AS usuario_id,
    COALESCE(SUM(a.puntos), 0)::INTEGER AS puntos,
    COALESCE(n.nombre, 'Eco Semilla') AS nivel,
    COALESCE(n.puntos_minimos, 0) AS puntos_minimos_nivel,
    n.puntos_maximos AS puntos_maximos_nivel
FROM public.perfiles p
LEFT JOIN public.actividad_ecologica a ON a.usuario_id = p.id
LEFT JOIN public.niveles_ecologicos n ON n.id = (
    SELECT nivel.id
    FROM public.niveles_ecologicos nivel
    WHERE COALESCE((
        SELECT SUM(sub.puntos)
        FROM public.actividad_ecologica sub
        WHERE sub.usuario_id = p.id
    ), 0) >= nivel.puntos_minimos
      AND (
          nivel.puntos_maximos IS NULL
          OR COALESCE((
              SELECT SUM(sub2.puntos)
              FROM public.actividad_ecologica sub2
              WHERE sub2.usuario_id = p.id
          ), 0) <= nivel.puntos_maximos
      )
    ORDER BY nivel.orden DESC
    LIMIT 1
)
GROUP BY p.id, n.nombre, n.puntos_minimos, n.puntos_maximos;

-- ─── Funciones de autorización ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.es_operador()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE id = auth.uid() AND rol = 'operador' AND activo = TRUE
    );
$$;

CREATE OR REPLACE FUNCTION public.puede_gestionar_operacion()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT public.es_administrador() OR public.es_operador();
$$;

REVOKE ALL ON FUNCTION public.es_operador() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.puede_gestionar_operacion() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.es_operador() TO authenticated;
GRANT EXECUTE ON FUNCTION public.puede_gestionar_operacion() TO authenticated;

-- ─── Permisos ────────────────────────────────────────────────────────────────
GRANT SELECT ON public.camiones, public.rutas, public.horarios_recoleccion,
    public.tipos_residuo, public.niveles_ecologicos
    TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.recolecciones TO authenticated;
GRANT SELECT, UPDATE ON public.notificaciones TO authenticated;
GRANT SELECT ON public.actividad_ecologica TO authenticated;
GRANT SELECT ON public.auditoria TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.camiones, public.rutas,
    public.horarios_recoleccion, public.tipos_residuo TO authenticated;
GRANT INSERT ON public.notificaciones, public.actividad_ecologica TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

CREATE OR REPLACE FUNCTION public.obtener_resumen_ecologico()
RETURNS TABLE (
    usuario_id UUID,
    puntos INTEGER,
    nivel VARCHAR,
    puntos_minimos_nivel INTEGER,
    puntos_maximos_nivel INTEGER
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT usuario_id, puntos, nivel, puntos_minimos_nivel, puntos_maximos_nivel
    FROM public.resumen_ecologico
    WHERE usuario_id = auth.uid() OR public.es_administrador();
$$;

GRANT EXECUTE ON FUNCTION public.obtener_resumen_ecologico() TO authenticated;

-- ─── RLS ─────────────────────────────────────────────────────────────────────
ALTER TABLE public.camiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rutas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.horarios_recoleccion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipos_residuo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recolecciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.niveles_ecologicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.actividad_ecologica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auditoria_select_admin" ON public.auditoria;
CREATE POLICY "auditoria_select_admin" ON public.auditoria
    FOR SELECT TO authenticated
    USING (public.es_administrador());

DROP POLICY IF EXISTS "camiones_select_autenticados" ON public.camiones;
DROP POLICY IF EXISTS "camiones_gestion_admin" ON public.camiones;
CREATE POLICY "camiones_select_autenticados" ON public.camiones
    FOR SELECT TO authenticated
    USING (activo = TRUE);
CREATE POLICY "camiones_gestion_admin" ON public.camiones
    FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS "rutas_select_autenticados" ON public.rutas;
DROP POLICY IF EXISTS "rutas_gestion_admin" ON public.rutas;
CREATE POLICY "rutas_select_autenticados" ON public.rutas
    FOR SELECT TO authenticated
    USING (activo = TRUE);
CREATE POLICY "rutas_gestion_admin" ON public.rutas
    FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS "horarios_select_autenticados" ON public.horarios_recoleccion;
DROP POLICY IF EXISTS "horarios_gestion_admin" ON public.horarios_recoleccion;
CREATE POLICY "horarios_select_autenticados" ON public.horarios_recoleccion
    FOR SELECT TO authenticated
    USING (activo = TRUE);
CREATE POLICY "horarios_gestion_admin" ON public.horarios_recoleccion
    FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS "tipos_residuo_select_autenticados" ON public.tipos_residuo;
DROP POLICY IF EXISTS "tipos_residuo_gestion_admin" ON public.tipos_residuo;
CREATE POLICY "tipos_residuo_select_autenticados" ON public.tipos_residuo
    FOR SELECT TO authenticated
    USING (activo = TRUE);
CREATE POLICY "tipos_residuo_gestion_admin" ON public.tipos_residuo
    FOR ALL TO authenticated
    USING (public.es_administrador())
    WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS "recolecciones_select_propias" ON public.recolecciones;
DROP POLICY IF EXISTS "recolecciones_select_operacion" ON public.recolecciones;
DROP POLICY IF EXISTS "recolecciones_gestion_operacion" ON public.recolecciones;
CREATE POLICY "recolecciones_select_propias" ON public.recolecciones
    FOR SELECT TO authenticated
    USING (
        ciudadano_id = auth.uid()
        OR zona_id = (SELECT zona_id FROM public.perfiles WHERE id = auth.uid())
    );
CREATE POLICY "recolecciones_select_operacion" ON public.recolecciones
    FOR SELECT TO authenticated
    USING (public.puede_gestionar_operacion());
CREATE POLICY "recolecciones_gestion_operacion" ON public.recolecciones
    FOR ALL TO authenticated
    USING (public.puede_gestionar_operacion())
    WITH CHECK (public.puede_gestionar_operacion());

DROP POLICY IF EXISTS "notificaciones_select_propias" ON public.notificaciones;
DROP POLICY IF EXISTS "notificaciones_update_propias" ON public.notificaciones;
DROP POLICY IF EXISTS "notificaciones_insert_admin" ON public.notificaciones;
CREATE POLICY "notificaciones_select_propias" ON public.notificaciones
    FOR SELECT TO authenticated
    USING (usuario_id = auth.uid());
CREATE POLICY "notificaciones_update_propias" ON public.notificaciones
    FOR UPDATE TO authenticated
    USING (usuario_id = auth.uid())
    WITH CHECK (usuario_id = auth.uid());
CREATE POLICY "notificaciones_insert_admin" ON public.notificaciones
    FOR INSERT TO authenticated
    WITH CHECK (public.es_administrador());

DROP POLICY IF EXISTS "niveles_select_autenticados" ON public.niveles_ecologicos;
CREATE POLICY "niveles_select_autenticados" ON public.niveles_ecologicos
    FOR SELECT TO authenticated USING (TRUE);

DROP POLICY IF EXISTS "actividad_select_propias" ON public.actividad_ecologica;
DROP POLICY IF EXISTS "actividad_insert_admin" ON public.actividad_ecologica;
CREATE POLICY "actividad_select_propias" ON public.actividad_ecologica
    FOR SELECT TO authenticated
    USING (usuario_id = auth.uid() OR public.es_administrador());
CREATE POLICY "actividad_insert_admin" ON public.actividad_ecologica
    FOR INSERT TO authenticated
    WITH CHECK (public.es_administrador());

-- Solo administradores pueden asignar un nuevo nivel/actividad. Los ciudadanos
-- consultan la vista y no pueden editar su puntuación desde el cliente.
REVOKE INSERT, UPDATE, DELETE ON public.niveles_ecologicos FROM authenticated;
REVOKE UPDATE, DELETE ON public.actividad_ecologica FROM authenticated;

-- Impide que un ciudadano se asigne privilegios o reactive su cuenta mediante
-- un UPDATE directo. Los administradores conservan la capacidad de gestión.
CREATE OR REPLACE FUNCTION public.proteger_campos_privilegiados_perfil()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.es_administrador()
       AND current_user NOT IN ('postgres', 'supabase_admin')
       AND (
        NEW.rol IS DISTINCT FROM OLD.rol
        OR NEW.activo IS DISTINCT FROM OLD.activo
       )
    THEN
        RAISE EXCEPTION 'No puedes modificar los campos privilegiados del perfil';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_campos_privilegiados
    ON public.perfiles;
CREATE TRIGGER trg_proteger_campos_privilegiados
    BEFORE UPDATE ON public.perfiles
    FOR EACH ROW
    EXECUTE FUNCTION public.proteger_campos_privilegiados_perfil();

CREATE OR REPLACE FUNCTION public.evitar_ultimo_admin_inactivo()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.rol IN ('admin', 'administrador')
       AND OLD.activo = TRUE
       AND (
           NEW.activo = FALSE
           OR NEW.rol NOT IN ('admin', 'administrador')
       )
       AND (
           SELECT COUNT(*)
           FROM public.perfiles
           WHERE rol IN ('admin', 'administrador')
             AND activo = TRUE
             AND id <> OLD.id
       ) = 0
    THEN
        RAISE EXCEPTION 'No se puede dejar el sistema sin un administrador activo';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_evitar_ultimo_admin_inactivo
    ON public.perfiles;
CREATE TRIGGER trg_evitar_ultimo_admin_inactivo
    BEFORE UPDATE ON public.perfiles
    FOR EACH ROW
    EXECUTE FUNCTION public.evitar_ultimo_admin_inactivo();
