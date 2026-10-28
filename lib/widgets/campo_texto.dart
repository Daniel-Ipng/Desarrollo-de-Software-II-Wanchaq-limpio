import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colores_app.dart';

/// Campo de texto de EcoRutas: etiqueta encima y caja redondeada.
///
/// Si [esContrasena] es true incluye el botón para mostrar u ocultar el texto.
class CampoTexto extends StatefulWidget {
  final TextEditingController controlador;
  final String etiqueta;
  final String? pista;
  final IconData? icono;
  final bool esContrasena;
  final TextInputType tipoTeclado;
  final TextInputAction? accionTeclado;
  final TextCapitalization capitalizacion;
  final Iterable<String>? pistasAutocompletado;
  final String? Function(String?)? validador;
  final List<TextInputFormatter>? formateadores;
  final int maxLineas;
  final int? maxLongitud;
  final bool soloLectura;
  final void Function(String)? alCambiar;
  final void Function(String)? alEnviar;

  const CampoTexto({
    super.key,
    required this.controlador,
    required this.etiqueta,
    this.pista,
    this.icono,
    this.esContrasena = false,
    this.tipoTeclado = TextInputType.text,
    this.accionTeclado,
    this.capitalizacion = TextCapitalization.none,
    this.pistasAutocompletado,
    this.validador,
    this.formateadores,
    this.maxLineas = 1,
    this.maxLongitud,
    this.soloLectura = false,
    this.alCambiar,
    this.alEnviar,
  });

  /// Decoración común de los campos de formulario (también para dropdowns).
  static InputDecoration decoracion({
    String? pista,
    Widget? prefijo,
    Widget? sufijo,
    bool soloLectura = false,
  }) {
    return InputDecoration(
      hintText: pista,
      hintStyle: const TextStyle(color: ColoresApp.textoSuave),
      counterText: '',
      prefixIcon: prefijo,
      suffixIcon: sufijo,
      filled: true,
      fillColor: soloLectura ? ColoresApp.fondo : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _borde(ColoresApp.borde),
      enabledBorder: _borde(ColoresApp.borde),
      focusedBorder: _borde(ColoresApp.verde, ancho: 2),
      errorBorder: _borde(ColoresApp.error),
      focusedErrorBorder: _borde(ColoresApp.error, ancho: 2),
    );
  }

  static OutlineInputBorder _borde(Color color, {double ancho = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: ancho),
    );
  }

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  bool _ocultarTexto = true;

  @override
  Widget build(BuildContext context) {
    final esContrasena = widget.esContrasena;
    final esMultilinea = !esContrasena && widget.maxLineas > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.etiqueta,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColoresApp.etiqueta,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controlador,
          obscureText: esContrasena && _ocultarTexto,
          keyboardType: widget.tipoTeclado,
          textInputAction: widget.accionTeclado,
          textCapitalization: widget.capitalizacion,
          autofillHints: widget.pistasAutocompletado,
          minLines: esMultilinea ? 2 : null,
          maxLines: esContrasena ? 1 : widget.maxLineas,
          maxLength: widget.maxLongitud,
          inputFormatters: widget.formateadores,
          readOnly: widget.soloLectura,
          onChanged: widget.alCambiar,
          onFieldSubmitted: widget.alEnviar,
          validator: widget.validador,
          style: const TextStyle(fontSize: 15, color: ColoresApp.tinta),
          decoration: CampoTexto.decoracion(
            pista: widget.pista,
            soloLectura: widget.soloLectura,
            prefijo: widget.icono == null ? null : Icon(widget.icono),
            sufijo: esContrasena
                ? IconButton(
                    tooltip: _ocultarTexto
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    icon: Icon(
                      _ocultarTexto
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _ocultarTexto = !_ocultarTexto),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}