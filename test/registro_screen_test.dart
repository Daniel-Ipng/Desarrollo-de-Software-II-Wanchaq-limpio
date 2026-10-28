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
  testWidgets('registro en 3 pasos: exige aceptar la política y usa la zona elegida', (
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

    // Paso 1: datos (orden: nombres, apellidos, DNI, teléfono, correo, clave, confirmar)
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Ciudadana');
    await tester.enterText(campos.at(1), 'Prueba');
    await tester.enterText(campos.at(2), '12345678');
    await tester.enterText(campos.at(3), '');
    await tester.enterText(campos.at(4), 'ciudadana@example.test');
    await tester.enterText(campos.at(5), 'clave-segura');
    await tester.enterText(campos.at(6), 'clave-segura');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Paso 2: domicilio. La zona NO viene preseleccionada.
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona tu zona.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<Zona>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zona verificada').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Referencia del domicilio');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Paso 3: revisión. Sin aceptar la política no se registra.
    expect(find.text('Confirmar registro'), findsOneWidget);
    expect(find.text('clave-segura'), findsNothing);
    await tester.tap(find.text('Confirmar registro'));
    await tester.pumpAndSettle();
    expect(repositorio.llamadasRegistro, 0);

    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar registro'));
    await tester.pumpAndSettle();

    expect(registroCompletado, isTrue);
    expect(repositorio.llamadasRegistro, 1);
    expect(repositorio.zonaRecibida, 8);
  });
}