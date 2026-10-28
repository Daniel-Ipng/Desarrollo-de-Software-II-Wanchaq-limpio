import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/models/reporte.dart';
import 'package:mi_app/models/zona.dart';
import 'package:mi_app/repositories/reporte_repository.dart';
import 'package:mi_app/screens/crear_reporte_screen.dart';
import 'package:mi_app/services/api_service.dart';

class _ReporteCreado extends ReporteRepository {
  _ReporteCreado() : super(ApiService());

  @override
  Future<List<Zona>> listarZonasActivas() async => [];

  @override
  Future<ResultadoReporte> crear({
    required TipoIncidencia tipo,
    required String descripcion,
    required String zona,
    double? latitud,
    double? longitud,
  }) async {
    return ResultadoReporte.exitoso(
      Reporte(
        id: 1,
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
}

void main() {
  testWidgets('flujo guiado presenta cuatro pasos y permite enviar sin foto', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CrearReporteScreen(repositorio: _ReporteCreado()),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 4'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 2 de 4'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Zona o dirección aproximada'),
      'Wanchaq, Cusco',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 3 de 4'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción del problema'),
      'Residuos acumulados en la esquina de la calle.',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 4 de 4'), findsOneWidget);
    expect(find.textContaining('no se enviará ni almacenará'), findsOneWidget);

    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo reporte'), findsNothing);
  });
}
