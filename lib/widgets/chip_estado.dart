import 'package:flutter/material.dart';

import '../models/reporte.dart';
import '../theme/colores_app.dart';

/// Chip de estado que muestra el estado de un reporte con color semántico.
///
/// Paleta: naranja (pendiente), azul (en proceso) y verde (resuelto).
class ChipEstado extends StatelessWidget {
  final EstadoReporte estado;

  const ChipEstado({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    // (color del texto e ícono, color de fondo, ícono)
    final (color, fondo, icono) = switch (estado) {
      EstadoReporte.pendiente => (
        ColoresApp.advertencia,
        const Color(0xFFFEF0DC),
        Icons.schedule,
      ),
      EstadoReporte.enProceso => (
        const Color(0xFF1D5FBF),
        const Color(0xFFE3EDFB),
        Icons.autorenew,
      ),
      EstadoReporte.resuelto => (
        ColoresApp.verde,
        ColoresApp.verdeClaro,
        Icons.check,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
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
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}