import 'package:flutter/material.dart';

import '../models/modulos_ciudadanos.dart';
import '../repositories/reporte_repository.dart';

class HistorialRecoleccionesScreen extends StatefulWidget {
  final ReporteRepository repositorio;
  final int? zonaId;

  const HistorialRecoleccionesScreen({
    super.key,
    required this.repositorio,
    this.zonaId,
  });

  @override
  State<HistorialRecoleccionesScreen> createState() =>
      _HistorialRecoleccionesScreenState();
}

class _HistorialRecoleccionesScreenState
    extends State<HistorialRecoleccionesScreen> {
  List<Recoleccion> _items = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (widget.zonaId == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final items = await widget.repositorio.listarRecoleccionesPropias(
        zonaId: widget.zonaId!,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = 'No se pudo cargar el historial.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(
      0,
      (sum, item) => sum + (item.cantidadKg ?? 0),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de recolecciones')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.zonaId == null)
                    const Text(
                      'No tienes una zona asignada. No se pueden consultar recolecciones.',
                    )
                  else ...[
                    Text(
                      'Total registrado en tu zona: ${total.toStringAsFixed(2)} kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_items.isEmpty)
                      const Text('No hay recolecciones registradas.')
                    else
                      ..._items.map(
                        (item) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.recycling_outlined),
                            title: Text(item.tipoResiduo),
                            subtitle: Text(
                              '${item.fecha.toLocal().toString().split('.').first}\n'
                              '${item.observaciones ?? 'Sin observaciones'}',
                            ),
                            trailing: Text(
                              item.cantidadKg == null
                                  ? 'Sin kg'
                                  : '${item.cantidadKg!.toStringAsFixed(2)} kg',
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
