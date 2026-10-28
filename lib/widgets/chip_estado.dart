import 'package:flutter/material.dart';
import '../models/reporte.dart';

/// Chip de estado que muestra el estado de un reporte con color semántico.
class ChipEstado extends StatelessWidget {
  final EstadoReporte estado;

  const ChipEstado({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (color, icono) = switch (estado) {
      EstadoReporte.pendiente => (Colors.orange, Icons.schedule),
      EstadoReporte.enProceso => (Colors.blue, Icons.autorenew),
      EstadoReporte.resuelto => (Colors.green, Icons.check_circle),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            estado.etiqueta,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
