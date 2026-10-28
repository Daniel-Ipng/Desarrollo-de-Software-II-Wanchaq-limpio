import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/models/reporte.dart';
import 'package:mi_app/repositories/reporte_repository.dart';
import 'package:mi_app/screens/reportes_screen.dart';
import 'package:mi_app/services/api_service.dart';

class _ReportesDePrueba extends ReporteRepository {
  _ReportesDePrueba() : super(ApiService());

  @override
  Future<List<Reporte>> listar() async => [
    Reporte(
      id: 1,
      ciudadanoId: 4,
      tipo: TipoIncidencia.residuosAcumulados,
      descripcion: 'Incidencia pendiente de revisión',
      zona: 'Zona pendiente',
      estado: EstadoReporte.pendiente,
      creadoEn: DateTime(2026, 10, 25),
    ),
    Reporte(
      id: 2,
      ciudadanoId: 4,
      tipo: TipoIncidencia.contenedorLleno,
      descripcion: 'Contenedor atendido',
      zona: 'Zona resuelta',
      estado: EstadoReporte.resuelto,
      creadoEn: DateTime(2026, 10, 24),
    ),
  ];
}

void main() {
  testWidgets('filtra los reportes obtenidos por estado', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ReportesScreen(repositorio: _ReportesDePrueba())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zona pendiente'), findsOneWidget);
    expect(find.text('Zona resuelta'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Pendiente'));
    await tester.pumpAndSettle();

    expect(find.text('Zona pendiente'), findsOneWidget);
    expect(find.text('Zona resuelta'), findsNothing);
  });
}
