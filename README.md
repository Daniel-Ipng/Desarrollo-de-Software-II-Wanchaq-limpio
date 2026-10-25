# EcoRutas Wanchaq — App ciudadana (MVP en Flutter)

Consume el mismo backend Node/Express del proyecto web (`/api`).

## Pasos

1. Crea el proyecto base y copia esta carpeta `lib/` y el `pubspec.yaml` encima:
   ```
   flutter create ecocusco_app
   ```
   (usa `com.example.ecocusco_app` como nombre de paquete, o cambia `userAgentPackageName` en `mapa_screen.dart`).
2. `flutter pub get`
3. En `android/app/src/main/AndroidManifest.xml`, antes de `<application>`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   ```
4. Ejecuta con el backend de Render (por defecto):
   ```
   flutter run
   ```
   o con tu backend local (celular y PC en la misma red Wi-Fi):
   ```
   flutter run --dart-define=API_BASE=http://IP_DE_TU_PC:4000/api
   ```
   Para `http://` (sin HTTPS) agrega `android:usesCleartextTraffic="true"` en la etiqueta `<application>`.

## Cuenta de prueba (datos semilla)

Ciudadano: `mario.ccahuana@gmail.com` / `Vecino2024`

## Notas

- La primera petición a Render puede tardar ~30 s (el plan gratuito se "duerme").
- Operadores y admins usan 2FA por correo: en el MVP la app es solo para ciudadanos.
- El mapa usa OpenStreetMap (sin API key), igual que la versión web con Leaflet.
