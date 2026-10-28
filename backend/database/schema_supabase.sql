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
