import 'package:flutter/material.dart';

/// Botón primario reutilizable con estado de carga integrado.
class BotonPrimario extends StatelessWidget {
  final String etiqueta;
  final VoidCallback? alPresionar;
  final bool cargando;
  final IconData? icono;

  const BotonPrimario({
    super.key,
    required this.etiqueta,
    required this.alPresionar,
    this.cargando = false,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: cargando ? null : alPresionar,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: cargando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    etiqueta,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
