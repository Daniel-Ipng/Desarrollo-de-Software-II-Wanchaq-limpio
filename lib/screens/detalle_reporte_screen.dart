import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/reporte.dart';
import '../repositories/reporte_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/chip_estado.dart';

class DetalleReporteScreen extends StatefulWidget {
  final int reporteId;
  final ReporteRepository repositorio;
  final VoidCallback? alExpirarSesion;

  const DetalleReporteScreen({
    super.key,
    required this.reporteId,
    required this.repositorio,
    this.alExpirarSesion,
  });

  @override
  State<DetalleReporteScreen> createState() => _DetalleReporteScreenState();
}

class _DetalleReporteScreenState extends State<DetalleReporteScreen> {
  Reporte? _reporte;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final reporte = await widget.repositorio.obtener(widget.reporteId);
      if (mounted) {
        setState(() {
          _reporte = reporte;
          _cargando = false;
        });
      }
    } on AuthException catch (_) {
      widget.alExpirarSesion?.call();
      return;
    } catch (_) {
      _establecerError();
    }
  }

  void _establecerError() {
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = 'No se pudo cargar el detalle. Intenta nuevamente.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del reporte')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del reporte')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _cargarDetalle,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _construirDetalle(context, _reporte!);
  }

  Widget _construirDetalle(BuildContext context, Reporte reporte) {
    final colores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del reporte')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colores.primary, const Color(0xFF45A477)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.assignment_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reporte.tipo.etiqueta,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ChipEstado(estado: reporte.estado),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (reporte.imagenUrl?.isNotEmpty == true) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      reporte.imagenUrl!,
                      fit: BoxFit.cover,
                      height: 230,
                      errorBuilder: (_, _, _) => Container(
                        height: 140,
                        alignment: Alignment.center,
                        color: colores.surfaceContainerHighest,
                        child: const Text('No se pudo cargar la fotografía.'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _campo(
                  context,
                  'Descripción',
                  reporte.descripcion,
                  Icons.notes_outlined,
                ),
                _campo(
                  context,
                  'Zona o dirección',
                  reporte.zona,
                  Icons.place_outlined,
                ),
                _campo(
                  context,
                  'Fecha y hora registrada',
                  _formatearFecha(reporte.creadoEn.toLocal()),
                  Icons.schedule,
                ),
                _campo(
                  context,
                  'Número de reporte',
                  '#${reporte.id}',
                  Icons.tag,
                ),
                if (_tieneCoordenadas(reporte)) ...[
                  _campo(
                    context,
                    'Coordenadas GPS',
                    'Latitud: ${reporte.latitud!.toStringAsFixed(6)}\n'
                        'Longitud: ${reporte.longitud!.toStringAsFixed(6)}',
                    Icons.my_location,
                  ),
                  _mapaReporte(
                    context,
                    reporte,
                  ),
                ] else
                  _campo(
                    context,
                    'Ubicación GPS',
                    'Este reporte no tiene coordenadas GPS.',
                    Icons.location_off_outlined,
                  ),
                if (reporte.imagenUrl == null)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: colores.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Este reporte no tiene una fotografía almacenada.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _tieneCoordenadas(Reporte reporte) {
    final latitud = reporte.latitud;
    final longitud = reporte.longitud;
    return latitud != null &&
        longitud != null &&
        latitud.isFinite &&
        longitud.isFinite &&
        latitud >= -90 &&
        latitud <= 90 &&
        longitud >= -180 &&
        longitud <= 180;
  }

  Widget _campo(
    BuildContext context,
    String etiqueta,
    String valor,
    IconData icono,
  ) {
    final colores = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: colores.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiqueta,
                    style: TextStyle(
                      fontSize: 12,
                      color: colores.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(valor, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapaReporte(BuildContext context, Reporte reporte) {
    final colores = Theme.of(context).colorScheme;
    final punto = LatLng(reporte.latitud!, reporte.longitud!);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 10),
            child: Row(
              children: [
                Icon(Icons.map_outlined, color: colores.primary),
                const SizedBox(width: 12),
                const Text(
                  'Ubicación en el mapa',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(initialCenter: punto, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ecorutas.wanchaq',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: punto,
                      width: 52,
                      height: 52,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 44,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              'Mapa © OpenStreetMap contributors',
              style: TextStyle(
                fontSize: 11,
                color: colores.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} $hora:$minuto';
  }
}
