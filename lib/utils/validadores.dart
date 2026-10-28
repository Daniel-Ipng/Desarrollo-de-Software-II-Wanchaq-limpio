/// Validadores de formularios de autenticación (puros y fáciles de probar).
enum FortalezaContrasena { debil, media, fuerte }

String? validarRequerido(String? valor) {
  if (valor == null || valor.trim().isEmpty) {
    return 'Este campo es obligatorio.';
  }
  return null;
}

String? validarCorreo(String? valor) {
  if (valor == null || valor.trim().isEmpty) {
    return 'Ingresa tu correo electrónico';
  }
  if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(valor.trim())) {
    return 'Ingresa un correo válido';
  }
  return null;
}

String? validarContrasenaDeInicio(String? valor) {
  if (valor == null || valor.isEmpty) return 'Ingresa tu contraseña';
  return null;
}

String? validarDni(String? valor) {
  if (valor == null || !RegExp(r'^\d{8}$').hasMatch(valor)) {
    return 'El DNI debe tener ocho dígitos.';
  }
  return null;
}

/// El teléfono es opcional; si se escribe debe ser un celular peruano.
String? validarTelefonoOpcional(String? valor) {
  if (valor == null || valor.isEmpty) return null;
  if (!RegExp(r'^9\d{8}$').hasMatch(valor)) {
    return 'Ingresa un celular válido: 9 dígitos que empiecen en 9.';
  }
  return null;
}

String? validarContrasenaNueva(String? valor) {
  if (valor == null || valor.length < 8) return 'Mínimo ocho caracteres.';
  return null;
}

String? validarDireccion(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Escribe una dirección o referencia.';
  if (texto.length > 500) return 'Máximo 500 caracteres.';
  return null;
}

FortalezaContrasena calcularFortaleza(String contrasena) {
  var puntos = 0;
  if (contrasena.length >= 8) puntos++;
  if (RegExp(r'[A-Za-z]').hasMatch(contrasena) &&
      RegExp(r'\d').hasMatch(contrasena)) {
    puntos++;
  }
  if (contrasena.length >= 12 ||
      RegExp(r'[^A-Za-z0-9]').hasMatch(contrasena)) {
    puntos++;
  }
  if (puntos >= 3) return FortalezaContrasena.fuerte;
  if (puntos == 2) return FortalezaContrasena.media;
  return FortalezaContrasena.debil;
}