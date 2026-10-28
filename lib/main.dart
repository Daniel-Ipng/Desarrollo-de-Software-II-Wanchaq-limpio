import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/usuario.dart';
import 'repositories/usuario_repository.dart';
import 'repositories/reporte_repository.dart';
import 'screens/login_screen.dart';
import 'screens/inicio_screen.dart';
import 'screens/reportes_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/mapa_screen.dart';

/// Configuración pública del proyecto Supabase.
///
/// Se inyecta al compilar para no guardar las credenciales del proyecto en el
/// código fuente:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUri = Uri.tryParse(_supabaseUrl);
  if (_supabaseUrl.isEmpty ||
      _supabasePublishableKey.isEmpty ||
      supabaseUri == null ||
      supabaseUri.scheme != 'https' ||
      supabaseUri.host.isEmpty ||
      (supabaseUri.path.isNotEmpty && supabaseUri.path != '/')) {
    runApp(
      ConfiguracionSupabaseFaltante(
        mensaje:
            _supabaseUrl.isNotEmpty &&
                (supabaseUri == null ||
                    supabaseUri.scheme != 'https' ||
                    supabaseUri.host.isEmpty ||
                    (supabaseUri.path.isNotEmpty && supabaseUri.path != '/'))
            ? 'SUPABASE_URL debe ser la URL API del proyecto, por ejemplo '
                  'https://abcdefghijklmnop.supabase.co, sin /rest/v1 ni '
                  'la URL del Dashboard.'
            : null,
      ),
    );
    return;
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );

  runApp(const EcoRutasApp());
}

class ConfiguracionSupabaseFaltante extends StatelessWidget {
  final String? mensaje;

  const ConfiguracionSupabaseFaltante({super.key, this.mensaje});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              mensaje ??
                  'Falta configurar SUPABASE_URL y '
                      'SUPABASE_PUBLISHABLE_KEY. Ejecuta la app con '
                      '--dart-define.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Punto de entrada de la aplicación EcoRutas Wanchaq.
///
/// Configura el tema Material 3 con paleta ambiental (verde) e inicializa
/// las dependencias compartidas: [UsuarioRepository] y [ReporteRepository].
class EcoRutasApp extends StatelessWidget {
  const EcoRutasApp({super.key});

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF167D52);

    // Dependencias compartidas en toda la app (instancia única).
    final usuarioRepo = UsuarioRepository();
    final reporteRepo = ReporteRepository();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoRutas Wanchaq',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: verde,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F8F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F8F7),
          foregroundColor: Color(0xFF183D2D),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF10251D),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD8E2DF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD8E2DF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: verde, width: 2),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFD7F1E5),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: PantallaRaiz(usuarioRepo: usuarioRepo, reporteRepo: reporteRepo),
    );
  }
}

// ─── Pantalla raíz con gestión de autenticación ──────────────────────────────

/// Pantalla raíz que controla si se muestra Login o la app principal,
/// basándose en si existe una sesión guardada en Supabase.
class PantallaRaiz extends StatefulWidget {
  final UsuarioRepository usuarioRepo;
  final ReporteRepository reporteRepo;

  const PantallaRaiz({
    super.key,
    required this.usuarioRepo,
    required this.reporteRepo,
  });

  @override
  State<PantallaRaiz> createState() => _PantallaRaizState();
}

class _PantallaRaizState extends State<PantallaRaiz> {
  Usuario? _usuario;
  bool _verificando = true;
  String? _errorSesion;

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    setState(() {
      _verificando = true;
      _errorSesion = null;
    });
    try {
      final haySession = await widget.usuarioRepo.restaurarSesion();
      if (haySession) {
        final usuario = await widget.usuarioRepo.obtenerPerfil();
        if (mounted) setState(() => _usuario = usuario);
      }
    } on AuthException catch (error) {
      if (error.statusCode == '401' || error.message.contains('session')) {
        await widget.usuarioRepo.cerrarSesion();
        if (mounted) setState(() => _usuario = null);
      } else {
        _establecerErrorSesion();
      }
    } catch (_) {
      _establecerErrorSesion();
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  // Callback usado por LoginScreen y RegistroScreen.
  void _alAutenticar() {
    _cargarUsuarioAutenticado();
  }

  Future<void> _cargarUsuarioAutenticado() async {
    try {
      final usuario = await widget.usuarioRepo.obtenerPerfil();
      if (mounted) {
        setState(() {
          _usuario = usuario;
          _errorSesion = null;
        });
      }
    } on AuthException catch (error) {
      if (error.statusCode == '401' || error.message.contains('session')) {
        await _cerrarSesion();
      } else {
        _establecerErrorSesion();
      }
    } catch (_) {
      _establecerErrorSesion();
    }
  }

  Future<void> _cerrarSesion() async {
    await widget.usuarioRepo.cerrarSesion();
    if (mounted) {
      setState(() {
        _usuario = null;
        _errorSesion = null;
      });
    }
  }

  void _establecerErrorSesion() {
    if (!mounted) return;
    setState(() {
      _usuario = null;
      _errorSesion = 'No se pudo verificar la sesión. Comprueba tu conexión e inténtalo de nuevo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_verificando) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco, size: 64, color: Color(0xFF167D52)),
              SizedBox(height: 16),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (_errorSesion != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 16),
                Text(_errorSesion!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _verificarSesion,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_usuario == null) {
      return LoginScreen(
        repositorio: widget.usuarioRepo,
        alIniciarSesion: _alAutenticar,
      );
    }

    if (_usuario!.esAdministrador) {
      return AdminDashboardScreen(
        usuario: _usuario!,
        repositorio: widget.usuarioRepo,
        alCerrarSesion: _cerrarSesion,
      );
    }

    return AppPrincipal(
      usuario: _usuario!,
      repositorioReportes: widget.reporteRepo,
      repositorioUsuario: widget.usuarioRepo,
      alCerrarSesion: _cerrarSesion,
    );
  }
}

// ─── Aplicación principal (usuario autenticado) ──────────────────────────────

/// Shell con barra de navegación inferior para el usuario autenticado.
class AppPrincipal extends StatefulWidget {
  final Usuario usuario;
  final ReporteRepository repositorioReportes;
  final UsuarioRepository repositorioUsuario;
  final VoidCallback alCerrarSesion;

  const AppPrincipal({
    super.key,
    required this.usuario,
    required this.repositorioReportes,
    required this.repositorioUsuario,
    required this.alCerrarSesion,
  });

  @override
  State<AppPrincipal> createState() => _AppPrincipalState();
}

class _AppPrincipalState extends State<AppPrincipal> {
  int _indice = 0;
  late Usuario _usuario;

  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario;
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      InicioScreen(
        usuario: _usuario,
        repositorioReportes: widget.repositorioReportes,
        repositorioUsuario: widget.repositorioUsuario,
        alCerrarSesion: widget.alCerrarSesion,
        alIrAReportes: () => setState(() => _indice = 1),
        alIrAMapa: () => setState(() => _indice = 2),
        alIrAPerfil: () => setState(() => _indice = 3),
      ),
      ReportesScreen(
        repositorio: widget.repositorioReportes,
        zonaInicial: _usuario.zonaNombre,
        alExpirarSesion: widget.alCerrarSesion,
      ),
      MapaScreen(
        repositorio: widget.repositorioReportes,
        alExpirarSesion: widget.alCerrarSesion,
      ),
      PerfilScreen(
        repositorio: widget.repositorioUsuario,
        alExpirarSesion: widget.alCerrarSesion,
        alActualizarPerfil: (usuario) => setState(() => _usuario = usuario),
      ),
    ];

    return Scaffold(
      appBar: _indice == 1 || _indice == 2
          ? null
          : AppBar(
              title: const Row(
                children: [
                  Icon(Icons.eco, color: Color(0xFF167D52)),
                  SizedBox(width: 8),
                  Text(
                    'EcoRutas Wanchaq',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Notificaciones',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Las notificaciones aún no están disponibles.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                IconButton(
                  tooltip: 'Mi perfil',
                  onPressed: () => setState(() => _indice = 3),
                  icon: const Icon(Icons.person_outline),
                ),
                PopupMenuButton<String>(
                  icon: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Text(
                      _usuario.nombres.isNotEmpty
                          ? _usuario.nombres[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onSelected: (valor) {
                    if (valor == 'cerrar') _confirmarCierreSesion();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _usuario.nombreCompleto,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _usuario.correo,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'cerrar',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 18),
                          SizedBox(width: 8),
                          Text('Cerrar sesión'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: SafeArea(
        child: IndexedStack(index: _indice, children: pantallas),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarCierreSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar == true) widget.alCerrarSesion();
  }
}
