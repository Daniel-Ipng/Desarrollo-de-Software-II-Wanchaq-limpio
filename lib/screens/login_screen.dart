import 'package:flutter/material.dart';
import '../repositories/usuario_repository.dart';
import '../widgets/campo_texto.dart';
import '../widgets/boton_primario.dart';
import 'registro_screen.dart';

/// Pantalla de inicio de sesión.
///
/// Comunica con [UsuarioRepository] para autenticar al ciudadano y
/// navega a [InicioScreen] en caso de éxito.
class LoginScreen extends StatefulWidget {
  final UsuarioRepository repositorio;
  final VoidCallback alIniciarSesion;

  const LoginScreen({
    super.key,
    required this.repositorio,
    required this.alIniciarSesion,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();

  bool _cargando = false;
  bool _verContrasena = false;
  String? _errorGlobal;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorGlobal = null;
    });

    final resultado = await widget.repositorio.iniciarSesion(
      correo: _correoCtrl.text.trim(),
      contrasena: _contrasenaCtrl.text,
    );

    if (!mounted) return;

    if (resultado.exito) {
      widget.alIniciarSesion();
    } else {
      setState(() {
        _cargando = false;
        _errorGlobal = resultado.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colores.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ─── Encabezado ──────────────────────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colores.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.eco,
                    size: 40,
                    color: colores.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'EcoRutas Wanchaq',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colores.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Inicia sesión para continuar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colores.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),

                // ─── Formulario ───────────────────────────────────────────────
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CampoTexto(
                        controlador: _correoCtrl,
                        etiqueta: 'Correo electrónico',
                        icono: Icons.email_outlined,
                        tipoTeclado: TextInputType.emailAddress,
                        validador: _validarCorreo,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contrasenaCtrl,
                        obscureText: !_verContrasena,
                        validator: _validarContrasena,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _verContrasena
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(
                                () => _verContrasena = !_verContrasena,
                              );
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colores.outline.withAlpha(100),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colores.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: colores.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ─── Mensaje de error global ───────────────────────────
                      if (_errorGlobal != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colores.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colores.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorGlobal!,
                                  style: TextStyle(color: colores.error),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),
                      BotonPrimario(
                        etiqueta: 'Iniciar sesión',
                        alPresionar: _iniciarSesion,
                        cargando: _cargando,
                        icono: Icons.login,
                      ),
                      const SizedBox(height: 20),

                      // ─── Enlace a registro ────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '¿No tienes cuenta? ',
                            style: TextStyle(color: colores.onSurfaceVariant),
                          ),
                          TextButton(
                            onPressed: _irARegistro,
                            child: const Text('Regístrate'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _irARegistro() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegistroScreen(
          repositorio: widget.repositorio,
          alRegistrarse: widget.alIniciarSesion,
        ),
      ),
    );
  }

  // ─── Validaciones ─────────────────────────────────────────────────────────

  String? _validarCorreo(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa tu correo electrónico';
    }
    final expresion = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');
    if (!expresion.hasMatch(valor.trim())) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  String? _validarContrasena(String? valor) {
    if (valor == null || valor.isEmpty) return 'Ingresa tu contraseña';
    if (valor.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
    return null;
  }
}
