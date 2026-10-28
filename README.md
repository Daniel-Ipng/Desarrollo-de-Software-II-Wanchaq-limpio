# EcoRutas Wanchaq

Aplicación Flutter para registrar incidencias de residuos y consultar su estado
con Supabase Auth, PostgreSQL, Storage y RLS.

## Configuración de Supabase

1. Crea un proyecto en Supabase.
2. Ejecuta [`backend/database/schema_supabase.sql`](backend/database/schema_supabase.sql)
   en el SQL Editor.
3. El archivo `schema_supabase.sql` ya incluye las tablas, relaciones y
   políticas RLS de los módulos ciudadanos, administrativos y operativos.
4. En Storage crea un bucket público llamado `reportes`.
5. Obtén la URL del proyecto y la publishable key desde **Project Settings >
   API**.
6. Inicia la app inyectando la configuración:

```bash
flutter run --dart-define=SUPABASE_URL=https://tvlxdjhbxrqtxxxsprde.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_2XSV3ulWROSJY1YGE-lP0g_FfCrtZ0l
```

`SUPABASE_URL` debe ser la URL API, por ejemplo
`https://abcdefghijklmnop.supabase.co`. No uses la URL del Dashboard, una URL
que termine en `/rest/v1`, ni la URL de Auth.

La clave incluida arriba es la **publishable key** del cliente Flutter. No
reemplaces ese valor por una clave `service_role`, `secret` o cualquier otra
clave privada.

La aplicación muestra una pantalla de configuración faltante si alguna variable
no fue proporcionada. Nunca sustituyas la publishable key por una
`service_role` key.

## Panel administrativo

Las cuentas con rol `admin` o `administrador` acceden automáticamente al panel
administrativo después de iniciar sesión. El panel permite:

- consultar indicadores reales de usuarios por rol, camiones, zonas, rutas,
  recolecciones e incidencias;
- filtrar incidencias por estado y actualizar su estado;
- visualizar en un mapa OpenStreetMap las incidencias que tienen coordenadas
  GPS;
- consultar y activar o desactivar perfiles autorizados;
- registrar y editar camiones, zonas y tipos de residuos;
- consultar rutas y datos operativos existentes;
- registrar cambios administrativos en la tabla `auditoria`;
- actualizar los datos con el botón de refresco o deslizando la pantalla.

Estas consultas y cambios dependen de las políticas administrativas del archivo
[`backend/database/schema_supabase.sql`](backend/database/schema_supabase.sql).
Si el panel no muestra reportes, vuelve a ejecutar ese esquema en el proyecto
Supabase y confirma que el usuario tenga un perfil activo con rol
`admin` o `administrador`.

La creación de usuarios de Supabase Auth (administradores u operadores) no se
realiza desde el cliente Flutter: requiere una invitación o una Edge Function
segura con privilegios de servidor. La aplicación no almacena ni envía
contraseñas administrativas.

## Módulo ciudadano

El inicio ciudadano muestra la fecha actual, el resumen real de sus reportes,
los estados de cada incidencia, accesos rápidos, avisos cuando faltan datos de
residencia y un estado ecológico informativo. El perfil permite actualizar los
datos autorizados, obtener la ubicación con permiso del dispositivo y cambiar
la contraseña verificando primero la contraseña actual mediante Supabase Auth.

El esquema crea las tablas necesarias para horarios de recolección, camiones,
rutas, recolecciones, notificaciones, catálogo de residuos y actividad
ecológica. Los datos operativos deben ser registrados por un administrador u
operador; el esquema no inventa recorridos, posiciones GPS, recolecciones ni
puntos históricos.

La función `obtener_resumen_ecologico()` devuelve únicamente el resumen del
usuario autenticado (o los resúmenes para un administrador autorizado). Las
recolecciones de zona no se atribuyen automáticamente como aportes personales:
`ciudadano_id` solo debe utilizarse cuando exista esa relación real.

## Validación

```bash
flutter analyze
flutter test
cd backend
npm test
```
