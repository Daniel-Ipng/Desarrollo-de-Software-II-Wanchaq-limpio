import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/models/usuario.dart';
import 'package:mi_app/models/reporte.dart';
import 'package:mi_app/models/zona.dart';
import 'package:mi_app/screens/login_screen.dart';
import 'package:mi_app/screens/registro_screen.dart';
import 'package:mi_app/screens/crear_reporte_screen.dart';
import 'package:mi_app/screens/inicio_screen.dart';
import 'package:mi_app/repositories/usuario_repository.dart';
import 'package:mi_app/repositories/reporte_repository.dart';
import 'package:mi_app/services/api_service.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Envuelve el widget en MaterialApp con tema EcoRutas para todas las pruebas.
Widget envolver(Widget child) {
  return MaterialApp(home: child, theme: ThemeData(useMaterial3: true));
}

/// Usuario de prueba predefinido.
Usuario usuarioDemo() => const Usuario(
  id: 1,
  nombres: 'María',
  apellidos: 'Quispe',
  dni: '12345678',
  correo: 'maria@test.com',
);

// ─── Stubs de repositorios ────────────────────────────────────────────────────

/// Stub de [UsuarioRepository] que rechaza todas las operaciones
/// (para probar estados de error sin conectar al servidor).
class UsuarioRepoFallido extends UsuarioRepository {
  UsuarioRepoFallido() : super(ApiService());

  @override
  Future<ResultadoAuth> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async => const ResultadoAuth.fallido('Credenciales incorrectas');

  @override
  Future<ResultadoAuth> registrar({
    required String nombres,
    required String apellidos,
    required String dni,
    required String correo,
    String? telefono,
    required String contrasena,
    required int zonaId,
    required String direccion,
    double? latitudDomicilio,
    double? longitudDomicilio,
  }) async => const ResultadoAuth.fallido('El correo ya está registrado');

  @override
  Future<List<Zona>> listarZonasActivas() async => [];
}

/// Stub de [ReporteRepository] con lista vacía y creación exitosa.
class ReporteRepoVacio extends ReporteRepository {
  ReporteRepoVacio() : super(ApiService());

  @override
  Future<List<Zona>> listarZonasActivas() async => [];

  @override
  Future<List<Reporte>> listar() async => [];

  @override
  Future<ResultadoReporte> crear({
    required TipoIncidencia tipo,
    required String descripcion,
    required String zona,
    double? latitud,
    double? longitud,
  }) async => ResultadoReporte.exitoso(
    Reporte(
      id: 99,
      ciudadanoId: 1,
      tipo: tipo,
      descripcion: descripcion,
      zona: zona,
      latitud: latitud,
      longitud: longitud,
      estado: EstadoReporte.pendiente,
      creadoEn: DateTime.now(),
    ),
  );
}

class ReporteRepoError extends ReporteRepository {
  ReporteRepoError() : super(ApiService());

  @override
  Future<List<Reporte>> listar() async {
    throw StateError('Error de prueba');
  }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ─── Modelo Usuario ──────────────────────────────────────────────────────────

  group('Modelo Usuario', () {
    test('nombreCompleto concatena nombres y apellidos', () {
      const u = Usuario(
        id: 1,
        nombres: 'Juan',
        apellidos: 'Pérez',
        dni: '12345678',
        correo: 'juan@test.com',
      );
      expect(u.nombreCompleto, equals('Juan Pérez'));
    });

    test('fromJson construye el modelo correctamente', () {
      final json = {
        'id': 5,
        'nombres': 'Ana',
        'apellidos': 'Mamani',
        'dni': '87654321',
        'correo': 'ana@test.com',
        'telefono': '987654321',
      };
      final u = Usuario.fromJson(json);
      expect(u.id, 5);
      expect(u.nombres, 'Ana');
      expect(u.telefono, '987654321');
    });

    test('toJson serializa correctamente sin campo teléfono opcional', () {
      final u = usuarioDemo();
      final json = u.toJson();
      expect(json['correo'], 'maria@test.com');
      expect(json.containsKey('telefono'), isFalse);
    });
  });

  // ─── Modelo Reporte ──────────────────────────────────────────────────────────

  group('Modelo Reporte', () {
    test('fromJson construye el modelo correctamente', () {
      final json = {
        'id': 10,
        'ciudadano_id': 1,
        'tipo': 'contenedorLleno',
        'descripcion': 'El contenedor está lleno',
        'zona': 'Av. Garcilaso',
        'estado': 'pendiente',
        'creado_en': '2026-01-15T10:00:00.000Z',
      };
      final r = Reporte.fromJson(json);
      expect(r.tipo, TipoIncidencia.contenedorLleno);
      expect(r.estado, EstadoReporte.pendiente);
    });

    test('EstadoReporte.fromString devuelve pendiente por defecto', () {
      expect(
        EstadoReporte.fromString('valorDesconocido'),
        EstadoReporte.pendiente,
      );
    });

    test('Todos los EstadoReporte tienen etiqueta no vacía', () {
      for (final estado in EstadoReporte.values) {
        expect(estado.etiqueta.isNotEmpty, isTrue);
      }
    });

    test('Todos los TipoIncidencia tienen etiqueta no vacía', () {
      for (final tipo in TipoIncidencia.values) {
        expect(tipo.etiqueta.isNotEmpty, isTrue);
      }
    });
  });

  // ─── LoginScreen ─────────────────────────────────────────────────────────────

  group('LoginScreen', () {
    testWidgets('muestra campos de correo y contraseña', (tester) async {
      await tester.pumpWidget(
        envolver(
          LoginScreen(
            repositorio: UsuarioRepoFallido(),
            alIniciarSesion: () {},
          ),
        ),
      );
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });

    testWidgets('valida correo vacío al intentar enviar', (tester) async {
      await tester.pumpWidget(
        envolver(
          LoginScreen(
            repositorio: UsuarioRepoFallido(),
            alIniciarSesion: () {},
          ),
        ),
      );

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();

      expect(find.text('Ingresa tu correo electrónico'), findsOneWidget);
    });

    testWidgets('muestra error cuando las credenciales son incorrectas', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          LoginScreen(
            repositorio: UsuarioRepoFallido(),
            alIniciarSesion: () {},
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'usuario@test.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'contrasena123');

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Credenciales incorrectas'), findsOneWidget);
    });

    testWidgets('navega a pantalla de registro al tocar el enlace', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          LoginScreen(
            repositorio: UsuarioRepoFallido(),
            alIniciarSesion: () {},
          ),
        ),
      );

      await tester.tap(find.text('Regístrate'));
      await tester.pumpAndSettle();

      expect(find.text('Crear cuenta ciudadana'), findsOneWidget);
    });
  });

  // ─── RegistroScreen ──────────────────────────────────────────────────────────

  group('RegistroScreen — validaciones', () {
    Widget pantalla() => envolver(
      RegistroScreen(repositorio: UsuarioRepoFallido(), alRegistrarse: () {}),
    );

    testWidgets('rechaza DNI con menos de 8 dígitos', (tester) async {
      await tester.pumpWidget(pantalla());
      await tester.pumpAndSettle();

      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Ana');
      await tester.enterText(campos.at(1), 'Quispe');
      await tester.enterText(campos.at(2), '1234');
      await tester.enterText(campos.at(3), 'ana@test.com');
      await tester.enterText(campos.at(5), 'password1');
      await tester.enterText(campos.at(6), 'password1');
      await tester.tap(find.text('Continuar'));
      await tester.pump();

      expect(find.text('El DNI debe tener ocho dígitos.'), findsOneWidget);
    });

    testWidgets('rechaza contraseñas que no coinciden', (tester) async {
      await tester.pumpWidget(pantalla());
      await tester.pumpAndSettle();

      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Ana');
      await tester.enterText(campos.at(1), 'Quispe');
      await tester.enterText(campos.at(2), '12345678');
      await tester.enterText(campos.at(3), 'ana@test.com');
      await tester.enterText(campos.at(5), 'password1');
      await tester.enterText(campos.at(6), 'diferente2');
      await tester.tap(find.text('Continuar'));
      await tester.pump();

      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    });
  });

  // ─── CrearReporteScreen ──────────────────────────────────────────────────────

  group('CrearReporteScreen', () {
    testWidgets('muestra el primer paso y los tipos disponibles', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(CrearReporteScreen(repositorio: ReporteRepoVacio())),
      );
      await tester.pump();

      expect(find.text('Paso 1 de 4'), findsOneWidget);
      expect(find.text('Problema'), findsOneWidget);
      expect(find.text('¿Qué problema deseas reportar?'), findsOneWidget);
    });

    testWidgets('muestra todos los tipos de incidencia', (tester) async {
      await tester.pumpWidget(
        envolver(CrearReporteScreen(repositorio: ReporteRepoVacio())),
      );
      await tester.pump();

      expect(find.text('Residuos acumulados'), findsOneWidget);
      expect(find.text('Contenedor lleno'), findsOneWidget);
      expect(find.text('Falta de recolección'), findsOneWidget);
    });
  });

  // ─── InicioScreen ────────────────────────────────────────────────────────────

  group('InicioScreen', () {
    testWidgets('muestra el nombre del ciudadano en el banner', (tester) async {
      await tester.pumpWidget(
        envolver(
          InicioScreen(
            usuario: usuarioDemo(),
            repositorioReportes: ReporteRepoVacio(),
            repositorioUsuario: UsuarioRepoFallido(),
            alCerrarSesion: () {},
            alIrAReportes: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('María'), findsWidgets);
    });

    testWidgets('muestra acciones rápidas de reporte', (tester) async {
      await tester.pumpWidget(
        envolver(
          InicioScreen(
            usuario: usuarioDemo(),
            repositorioReportes: ReporteRepoVacio(),
            repositorioUsuario: UsuarioRepoFallido(),
            alCerrarSesion: () {},
            alIrAReportes: () {},
          ),
        ),
      );
      // Esperar a que se complete la carga asíncrona de reportes.
      await tester.pumpAndSettle();
      expect(find.text('Reportar una incidencia'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Mis reportes'), 300);
      expect(find.text('Mis reportes'), findsOneWidget);
    });

    testWidgets('muestra error y opción de reintento si falla el resumen', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          InicioScreen(
            usuario: usuarioDemo(),
            repositorioReportes: ReporteRepoError(),
            repositorioUsuario: UsuarioRepoFallido(),
            alCerrarSesion: () {},
            alIrAReportes: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo cargar tu resumen. Intenta nuevamente.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
