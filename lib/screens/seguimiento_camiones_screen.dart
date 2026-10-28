import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/modulos_ciudadanos.dart';
import '../repositories/reporte_repository.dart';

class SeguimientoCamionesScreen extends StatefulWidget {
  final ReporteRepository repositorio;

  const SeguimientoCamionesScreen({super.key, required this.repositorio});

  @override
  State<SeguimientoCamionesScreen> createState() =>
      _SeguimientoCamionesScreenState();
}

class _SeguimientoCamionesScreenState
    extends State<SeguimientoCamionesScreen> {
  List<Camion> _camiones = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final camiones = await widget.repositorio.listarCamiones();
      if (mounted) {
        setState(() {
          _camiones = camiones;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = 'No se pudieron cargar los vehículos.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ubicados = _camiones.where(_ubicado).toList();
    final centro = ubicados.isEmpty
        ? const LatLng(-13.53195, -71.96746)
        : LatLng(ubicados.first.latitud!, ubicados.first.longitud!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de camiones'),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _camiones.isEmpty
          ? const Center(child: Text('No hay camiones disponibles.'))
          : Column(
              children: [
                Expanded(
                  child: ubicados.isEmpty
                      ? const Center(
                          child: Text(
                            'Hay camiones registrados, pero ninguno tiene una ubicación GPS válida.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : FlutterMap(
                          options: MapOptions(
                            initialCenter: centro,
                            initialZoom: 13,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.ecorutas.wanchaq',
                            ),
                            MarkerLayer(
                              markers: ubicados
                                  .map(
                                    (camion) => Marker(
                                      point: LatLng(
                                        camion.latitud!,
                                        camion.longitud!,
                                      ),
                                      width: 100,
                                      height: 55,
                                      child: Tooltip(
                                        message: camion.placa,
                                        child: Column(
                                          children: [
                                            Text(
                                              camion.placa,
                                              style: const TextStyle(
                                                backgroundColor: Colors.white,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.local_shipping,
                                              color: Colors.green,
                                              size: 32,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                ),
                if (_camiones.length > ubicados.length)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${_camiones.length - ubicados.length} camión(es) sin señal GPS.',
                    ),
                  ),
              ],
            ),
    );
  }

  bool _ubicado(Camion camion) =>
      camion.latitud != null &&
      camion.longitud != null &&
      camion.latitud!.isFinite &&
      camion.longitud!.isFinite;
}
