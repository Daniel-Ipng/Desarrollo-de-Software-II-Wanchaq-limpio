# EcoRutas Wanchaq

Aplicación Flutter para registrar incidencias de residuos y consultar su estado
con Supabase Auth, PostgreSQL, Storage y RLS.

## Configuración de Supabase

1. Crea un proyecto en Supabase.
2. Ejecuta [`backend/database/schema_supabase.sql`](backend/database/schema_supabase.sql)
   en el SQL Editor.
3. En Storage crea un bucket público llamado `reportes`.
4. Obtén la URL del proyecto y la publishable key desde **Project Settings >
   API**.
5. Inicia la app inyectando la configuración:

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

## Validación

```bash
flutter analyze
flutter test
cd backend
npm test
```
