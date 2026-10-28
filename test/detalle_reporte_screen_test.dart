import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/models/reporte.dart';
import 'package:mi_app/repositories/reporte_repository.dart';
import 'package:mi_app/screens/detalle_reporte_screen.dart';
import 'package:mi_app/services/api_service.dart';

class _ReporteDetalle extends ReporteRepository {
  final Reporte reporte;
  int lecturas = 0;

  _ReporteDetalle(this.reporte) : super(ApiService());

  @override
  Future<Reporte> obtener(int id) async {
    lecturas++;
    expect(id, reporte.id);
    return reporte;
  }
}

void main() {
  testWidgets('el detalle consulta el endpoint por id y muestra datos reales', (
    tester,
  ) async {
    final repositorio = _ReporteDetalle(
      Reporte(
        id: 51,
        ciudadanoId: 8,
        tipo: TipoIncidencia.otro,
        descripcion: 'Descripción obtenida en el detalle del reporte.',
        zona: 'Zona real',
        latitud: -13.53,
        longitud: -71.96,
        estado: EstadoReporte.enProceso,
        creadoEn: DateTime.utc(2026, 10, 25),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DetalleReporteScreen(reporteId: 51, repositorio: repositorio),
      ),
    );
    await tester.pumpAndSettle();

    expect(repositorio.lecturas, 1);
    expect(find.text('Zona real'), findsOneWidget);
    expect(
      find.text('Descripción obtenida en el detalle del reporte.'),
      findsOneWidget,
    );
    expect(find.text('En proceso'), findsOneWidget);
  });
}
