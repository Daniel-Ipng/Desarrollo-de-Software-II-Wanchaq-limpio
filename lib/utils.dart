import 'package:flutter/material.dart';

String tiempoRelativo(DateTime? f) {
  if (f == null) return 'sin datos';
  final d = DateTime.now().difference(f);
  if (d.inSeconds < 60) return 'hace ${d.inSeconds < 0 ? 0 : d.inSeconds} s';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}

String fmtFecha(DateTime? f) {
  if (f == null) return '';
  String d2(int n) => n.toString().padLeft(2, '0');
  return '${d2(f.day)}/${d2(f.month)}/${f.year} ${d2(f.hour)}:${d2(f.minute)}';
}

Color colorDesdeHex(String? hex, [Color fallback = Colors.green]) {
  if (hex == null) return fallback;
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return fallback;
  final v = int.tryParse('FF$h', radix: 16);
  return v == null ? fallback : Color(v);
}

void mensaje(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

class ErrorVista extends StatelessWidget {
  final String mensajeError;
  final VoidCallback onReintentar;
  const ErrorVista({super.key, required this.mensajeError, required this.onReintentar});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(mensajeError, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ]),
        ),
      );
}
