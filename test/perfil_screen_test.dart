import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/models/usuario.dart';
import 'package:mi_app/models/zona.dart';
import 'package:mi_app/repositories/usuario_repository.dart';
import 'package:mi_app/screens/perfil_screen.dart';
import 'package:mi_app/services/api_service.dart';

class UsuarioRepoPerfil extends UsuarioRepository {
  final Future<Usuario> Function() cargar;
  Usuario? usuarioActualizado;

  UsuarioRepoPerfil(this.cargar) : super(ApiService());

  @override
  Future<Usuario> obtenerPerfil() => cargar();

  @override
  Future<List<Zona>> listarZonasActivas() async => const [
    Zona(id: 3, nombre: 'Wanchaq'),
  ];

  @override
  Future<Usuario> actualizarPerfil({
    required String nombres,
    required String apellidos,
    required String? telefono,
    required int zonaId,
    required String direccion,
    double? latitudDomicilio,
    double? longitudDomicilio,
  }) async {
    usuarioActualizado = Usuario(
      id: 7,
      nombres: nombres,
      apellidos: apellidos,
      dni: '12345678',
      correo: 'ana@example.com',
      telefono: telefono,
      zonaId: zonaId,
      zonaNombre: 'Wanchaq',
      direccion: direccion,
      latitudDomicilio: latitudDomicilio,
      longitudDomicilio: longitudDomicilio,
    );
    return usuarioActualizado!;
  }
}

Usuario usuarioPerfil() => Usuario.fromJson({
  'id': 7,
  'nombres': 'Ana',
  'apellidos': null,
  'dni': null,
  'correo': 'ana@example.com',
  'telefono': null,
});

Widget envolverPerfil({
  required UsuarioRepository repositorio,
  required VoidCallback alExpirarSesion,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PerfilScreen(
        repositorio: repositorio,
        alExpirarSesion: alExpirarSesion,
      ),
    ),
  );
}

void main() {
  testWidgets('muestra datos obtenidos y valores opcionales no registrados', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolverPerfil(
        repositorio: UsuarioRepoPerfil(() async => usuarioPerfil()),
        alExpirarSesion: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsNWidgets(2));
    expect(find.text('ana@example.com'), findsNWidgets(2));
    expect(find.text('No registrado'), findsNWidgets(3));
    expect(find.text('password_hash'), findsNothing);
    expect(find.text('token'), findsNothing);
  });

  testWidgets('muestra error y permite reintentar la carga', (tester) async {
    var intentos = 0;
    final repositorio = UsuarioRepoPerfil(() async {
      intentos++;
      if (intentos == 1) {
        throw const ApiException('Error interno', codigoHttp: 500);
      }
      return usuarioPerfil();
    });

    await tester.pumpWidget(
      envolverPerfil(repositorio: repositorio, alExpirarSesion: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(intentos, 2);
    expect(find.text('Ana'), findsNWidgets(2));
  });

  testWidgets('notifica la expiración de sesión al recibir HTTP 401', (
    tester,
  ) async {
    var sesionExpirada = false;
    await tester.pumpWidget(
      envolverPerfil(
        repositorio: UsuarioRepoPerfil(
          () async =>
              throw const ApiException('No autorizado', codigoHttp: 401),
        ),
        alExpirarSesion: () => sesionExpirada = true,
      ),
    );
    await tester.pump();

    expect(sesionExpirada, isTrue);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('edita y actualiza el perfil propio con zona activa', (
    tester,
  ) async {
    final repositorio = UsuarioRepoPerfil(() async => usuarioPerfil());
    await tester.pumpWidget(
      envolverPerfil(repositorio: repositorio, alExpirarSesion: () {}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ana María');
    await tester.enterText(find.byType(TextFormField).at(1), 'Pérez');
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'Dirección actualizada',
    );
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(repositorio.usuarioActualizado?.nombres, 'Ana María');
    expect(repositorio.usuarioActualizado?.apellidos, 'Pérez');
    expect(repositorio.usuarioActualizado?.zonaId, 3);
    expect(repositorio.usuarioActualizado?.direccion, 'Dirección actualizada');
  });
}
