# EcoRutas Wanchaq

Aplicación Flutter para registrar incidencias de residuos y consultar su estado
con Supabase Auth, PostgreSQL, Cloudinary y RLS.

## Configuración de Supabase

1. Crea un proyecto en Supabase.
2. Ejecuta [`backend/database/schema_supabase.sql`](backend/database/schema_supabase.sql)
   en el SQL Editor.
3. Crea una cuenta en Cloudinary. En **Settings > Upload > Upload presets**,
   crea un preset con **Signing mode: Unsigned** y anota tu **Cloud name**.
4. Obtén la URL del proyecto y la publishable key desde **Project Settings >
   API**.
5. Inicia la app inyectando la configuración de Cloudinary:

```bash
flutter run --dart-define=SUPABASE_URL=https://tvlxdjhbxrqtxxxsprde.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_2XSV3ulWROSJY1YGE-lP0g_FfCrtZ0l --dart-define=CLOUDINARY_CLOUD_NAME=dlojmprah --dart-define=CLOUDINARY_UPLOAD_PRESET=wanchaq
```

El mismo comando funciona en Flutter Web, Android emulado y dispositivos
Android físicos. No es necesario publicar el backend ni mantener la laptop
encendida para subir imágenes.

Las fotos de reportes se suben directamente a Cloudinary y la URL pública se guarda en
`reportes.imagen_url`; la imagen de fondo de la aplicación continúa siendo un
recurso local.

`SUPABASE_URL` debe ser la URL API, por ejemplo
`https://abcdefghijklmnop.supabase.co`. No uses la URL del Dashboard, una URL
que termine en `/rest/v1`, ni la URL de Auth.

La clave incluida arriba es la **publishable key** del cliente Flutter. No
reemplaces ese valor por una clave `service_role`, `secret` o cualquier otra
clave privada.

El `cloud_name` de Cloudinary debe ser el nombre real de la nube (por ejemplo,
`miappassets`), no el identificador `c-...` que aparece en la URL del
console. El preset unsigned es `wanchaq`.

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
