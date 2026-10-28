import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/models/usuario.dart';
import 'package:mi_app/models/zona.dart';
import 'package:mi_app/repositories/usuario_repository.dart';
import 'package:mi_app/screens/registro_screen.dart';

class _RegistroRepository extends UsuarioRepository {
  int llamadasRegistro = 0;
  int? zonaRecibida;

  _RegistroRepository();

  @override
  Future<List<Zona>> listarZonasActivas() async => const [
    Zona(id: 8, nombre: 'Zona verificada'),
  ];

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
  }) async {
    llamadasRegistro++;
    zonaRecibida = zonaId;
    return const ResultadoAuth.exitoso(
      Usuario(
        id: '5',
        nombres: 'Ciudadana',
        apellidos: 'Prueba',
        dni: '12345678',
        correo: 'ciudadana@example.test',
      ),
    );
  }
}

void main() {
  testWidgets('confirma registro solo desde el resumen y usa zona cargada', (
    tester,
  ) async {
    final repositorio = _RegistroRepository();
    var registroCompletado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RegistroScreen(
          repositorio: repositorio,
          alRegistrarse: () => registroCompletado = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 4'), findsOneWidget);
    expect(repositorio.llamadasRegistro, 0);
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Ciudadana');
    await tester.enterText(campos.at(1), 'Prueba');
    await tester.enterText(campos.at(2), '12345678');
    await tester.enterText(campos.at(3), 'ciudadana@example.test');
    await tester.enterText(campos.at(4), '');
    await tester.enterText(campos.at(5), 'clave-segura');
    await tester.enterText(campos.at(6), 'clave-segura');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 2 de 4'), findsOneWidget);
    expect(find.text('Zona verificada'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 3 de 4'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField),
      'Referencia del domicilio',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 4 de 4'), findsOneWidget);
    expect(find.text('clave-segura'), findsNothing);
    expect(repositorio.llamadasRegistro, 0);
    await tester.tap(find.text('Confirmar registro'));
    await tester.pumpAndSettle();

    expect(registroCompletado, isTrue);
    expect(repositorio.llamadasRegistro, 1);
    expect(repositorio.zonaRecibida, 8);
  });
}
