import 'package:flutter/material.dart';

/// Campo de texto reutilizable con estilo EcoRutas.
///
/// Encapsula [TextFormField] con validación, icono y tipo de teclado.
class CampoTexto extends StatelessWidget {
  final TextEditingController controlador;
  final String etiqueta;
  final String? pista;
  final IconData? icono;
  final bool esContrasena;
  final TextInputType tipoTeclado;
  final String? Function(String?)? validador;
  final int maxLineas;
  final bool soloLectura;
  final void Function(String)? alCambiar;

  const CampoTexto({
    super.key,
    required this.controlador,
    required this.etiqueta,
    this.pista,
    this.icono,
    this.esContrasena = false,
    this.tipoTeclado = TextInputType.text,
    this.validador,
    this.maxLineas = 1,
    this.soloLectura = false,
    this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      obscureText: esContrasena,
      keyboardType: tipoTeclado,
      maxLines: esContrasena ? 1 : maxLineas,
      readOnly: soloLectura,
      onChanged: alCambiar,
      validator: validador,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: pista,
        prefixIcon: icono != null ? Icon(icono) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(100),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: soloLectura
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
