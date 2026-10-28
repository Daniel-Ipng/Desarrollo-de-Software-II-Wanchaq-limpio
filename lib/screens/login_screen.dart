import 'package:flutter/material.dart';

import '../repositories/usuario_repository.dart';
import '../theme/colores_app.dart';
import '../utils/validadores.dart';
import '../widgets/boton_primario.dart';
import '../widgets/campo_texto.dart';
import 'registro_screen.dart';

/// Pantalla de inicio de sesión.
///
/// Autentica con [UsuarioRepository] y avisa con [alIniciarSesion] al tener éxito.
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

  Future<void> _abrirRecuperacion() async {
    final enviado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRecuperarContrasena(
        repositorio: widget.repositorio,
        correoInicial: _correoCtrl.text.trim(),
      ),
    );
    if (enviado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Te enviamos un enlace para restablecer tu contraseña.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.verde,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      const _EncabezadoLogin(),
                      Expanded(child: _tarjetaFormulario()),
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

  Widget _tarjetaFormulario() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Inicia sesión',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.tinta,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ingresa con tu correo y contraseña',
                style: TextStyle(
                  fontSize: 14,
                  color: ColoresApp.textoSecundario,
                ),
              ),
              const SizedBox(height: 20),
              CampoTexto(
                controlador: _correoCtrl,
                etiqueta: 'Correo electrónico',
                pista: 'tucorreo@gmail.com',
                tipoTeclado: TextInputType.emailAddress,
                accionTeclado: TextInputAction.next,
                pistasAutocompletado: const [AutofillHints.email],
                validador: validarCorreo,
              ),
              const SizedBox(height: 16),
              CampoTexto(
                controlador: _contrasenaCtrl,
                etiqueta: 'Contraseña',
                pista: 'Tu contraseña',
                esContrasena: true,
                accionTeclado: TextInputAction.done,
                pistasAutocompletado: const [AutofillHints.password],
                alEnviar: (_) => _iniciarSesion(),
                validador: validarContrasenaDeInicio,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _abrirRecuperacion,
                  style: TextButton.styleFrom(
                    foregroundColor: ColoresApp.verde,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              if (_errorGlobal != null) ...[
                _AvisoError(mensaje: _errorGlobal!),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              BotonPrimario(
                etiqueta: 'Iniciar sesión',
                alPresionar: _iniciarSesion,
                cargando: _cargando,
              ),
              const SizedBox(height: 22),
              const _SeparadorConTexto(texto: '¿Aún no tienes cuenta?'),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _irARegistro,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresApp.verde,
                    side: const BorderSide(color: ColoresApp.verde, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Crear cuenta ciudadana'),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Municipalidad Distrital de Wanchaq',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: ColoresApp.textoSecundario),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EncabezadoLogin extends StatelessWidget {
  const _EncabezadoLogin();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 36, 24, 30),
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.white,
            child: Icon(Icons.eco, size: 40, color: ColoresApp.verde),
          ),
          SizedBox(height: 14),
          Text(
            'EcoRutas Wanchaq',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Recolección de residuos en tu distrito',
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  final String mensaje;
  const _AvisoError({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresApp.errorFondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: ColoresApp.errorTexto, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: ColoresApp.errorTexto),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeparadorConTexto extends StatelessWidget {
  final String texto;
  const _SeparadorConTexto({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: ColoresApp.divisor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 13,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ),
        const Expanded(child: Divider(color: ColoresApp.divisor)),
      ],
    );
  }
}

/// Diálogo para pedir el enlace de restablecimiento de contraseña.
class _DialogoRecuperarContrasena extends StatefulWidget {
  final UsuarioRepository repositorio;
  final String correoInicial;

  const _DialogoRecuperarContrasena({
    required this.repositorio,
    required this.correoInicial,
  });

  @override
  State<_DialogoRecuperarContrasena> createState() =>
      _DialogoRecuperarContrasenaState();
}

class _DialogoRecuperarContrasenaState
    extends State<_DialogoRecuperarContrasena> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _correoCtrl = TextEditingController(
    text: widget.correoInicial,
  );
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });

    final resultado = await widget.repositorio.recuperarContrasena(
      _correoCtrl.text,
    );
    if (!mounted) return;

    if (resultado.exito) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _enviando = false;
        _error = resultado.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recuperar contraseña'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribe tu correo y te enviaremos un enlace para restablecerla.',
            ),
            const SizedBox(height: 16),
            CampoTexto(
              controlador: _correoCtrl,
              etiqueta: 'Correo electrónico',
              pista: 'tucorreo@gmail.com',
              tipoTeclado: TextInputType.emailAddress,
              accionTeclado: TextInputAction.done,
              alEnviar: (_) => _enviar(),
              validador: validarCorreo,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: ColoresApp.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: Text(_enviando ? 'Enviando...' : 'Enviar enlace'),
        ),
      ],
    );
  }
}