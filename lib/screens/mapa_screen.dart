import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../api.dart';
import '../config.dart';
import '../models.dart';
import '../utils.dart';

/// Seguimiento del camión. El backend emite por Socket.IO, pero para el MVP
/// se consulta GET /gps/activos cada 10 s (más simple y suficiente).
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});
  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final _mapa = MapController();
  Timer? _timer;
  List<CamionGps> _camiones = [];
  List<Zona> _zonas = [];
  String? _error;
  bool _primeraCarga = true;

  String? get _miZona => Api.sesion.value?.zona;

  @override
  void initState() {
    super.initState();
    _cargarZonas();
    _actualizar();
    _timer = Timer.periodic(Config.refrescoGps, (_) => _actualizar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarZonas() async {
    try {
      final z = await Api.zonas();
      if (mounted) setState(() => _zonas = z.where((e) => e.estado == 'activa').toList());
    } on ApiException {
      /* sin polígonos, el mapa sigue funcionando */
    }
  }

  Future<void> _actualizar() async {
    try {
      final lista = await Api.gpsActivos();
      if (!mounted) return;
      setState(() {
        _camiones = lista;
        _error = null;
        _primeraCarga = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _primeraCarga = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_primeraCarga) return const Center(child: CircularProgressIndicator());

    final centro = _camiones.isNotEmpty ? _camiones.first.punto : Config.centroWanchaq;

    return Column(children: [
      Expanded(
        child: FlutterMap(
          mapController: _mapa,
          options: MapOptions(initialCenter: centro, initialZoom: 14),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.ecocusco_app',
            ),
            PolygonLayer(
              polygons: _zonas.where((z) => z.poligono.length >= 3).map((z) {
                final mia = z.nombre == _miZona;
                final color = mia ? Colors.green : Colors.blueGrey;
                return Polygon(
                  points: z.poligono,
                  isFilled: true,
                  color: color.withOpacity(mia ? 0.30 : 0.10),
                  borderColor: color,
                  borderStrokeWidth: mia ? 3 : 1,
                );
              }).toList(),
            ),
            MarkerLayer(
              markers: _camiones.map((c) {
                final mio = c.zonaNombre != null && c.zonaNombre == _miZona;
                final color = c.senalPerdida
                    ? Colors.grey
                    : (mio ? Colors.green.shade800 : Colors.orange.shade800);
                return Marker(
                  point: c.punto,
                  width: mio ? 52 : 40,
                  height: mio ? 52 : 40,
                  child: GestureDetector(
                    onTap: () => _detalle(c),
                    child: Icon(Icons.local_shipping, color: color, size: mio ? 44 : 32),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      _panelInferior(),
    ]);
  }

  Widget _panelInferior() {
    return Material(
      elevation: 8,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 190),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _camiones.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error ?? 'No hay camiones en ruta en este momento.',
                    textAlign: TextAlign.center),
              )
            : ListView(
                shrinkWrap: true,
                children: _camiones.map((c) {
                  final mio = c.zonaNombre != null && c.zonaNombre == _miZona;
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.local_shipping,
                        color: c.senalPerdida ? Colors.grey : Colors.green),
                    title: Text('${c.placa ?? 'Camión'}${mio ? '  · Tu zona' : ''}'),
                    subtitle: Text(c.senalPerdida
                        ? 'Señal perdida · ${tiempoRelativo(c.fecha)}'
                        : '${c.zonaNombre ?? 'Sin zona'} · ${tiempoRelativo(c.fecha)}'),
                    onTap: () => _mapa.move(c.punto, 16),
                  );
                }).toList(),
              ),
      ),
    );
  }

  void _detalle(CamionGps c) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.placa ?? 'Camión', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Zona: ${c.zonaNombre ?? 'Sin asignar'}'),
          Text('Velocidad: ${c.velocidad != null ? '${c.velocidad} km/h' : 'No disponible'}'),
          Text('Última actualización: ${tiempoRelativo(c.fecha)}'),
        ]),
      ),
    );
  }
}
