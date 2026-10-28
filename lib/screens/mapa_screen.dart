import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reporte.dart';
import '../repositories/reporte_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/chip_estado.dart';

class MapaScreen extends StatefulWidget {
  final ReporteRepository repositorio;
  final VoidCallback? alExpirarSesion;

  const MapaScreen({
    super.key,
    required this.repositorio,
    this.alExpirarSesion,
  });

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  List<Reporte> _reportes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final reportes = await widget.repositorio.listar();
      if (!mounted) return;
      setState(() {
        _reportes = reportes;
        _cargando = false;
      });
    } on AuthException catch (_) {
      widget.alExpirarSesion?.call();
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las ubicaciones de tus reportes.';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final conCoordenadas = _reportes.where(_tieneCoordenadas).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de rutas')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _estado(
              icono: Icons.cloud_off_outlined,
              mensaje: _error!,
              accion: FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colores.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          color: colores.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Las ubicaciones GPS de tus reportes aparecen aquí. '
                            'No hay un proveedor de mapas embebido configurado; '
                            'puedes abrir coordenadas válidas en tu aplicación de mapas.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Ubicaciones con GPS (${conCoordenadas.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_reportes.isEmpty)
                    _estado(
                      icono: Icons.location_searching,
                      mensaje: 'Aún no hay reportes para mostrar.',
                    )
                  else if (conCoordenadas.isEmpty)
                    _estado(
                      icono: Icons.location_off_outlined,
                      mensaje:
                          'Tus reportes actuales no incluyen coordenadas GPS. '
                          'Puedes ver su zona en la sección Reportes.',
                    )
                  else
                    ...conCoordenadas.map(_tarjetaUbicacion),
                ],
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

  Widget _tarjetaUbicacion(Reporte reporte) {
    final latitud = reporte.latitud!;
    final longitud = reporte.longitud!;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.location_on_outlined)),
        title: Text(reporte.tipo.etiqueta),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reporte.zona),
            Text(
              '${latitud.toStringAsFixed(5)}, ${longitud.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 6),
            ChipEstado(estado: reporte.estado),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Abrir ubicación en mapas',
          onPressed: () => _abrirMapa(latitud, longitud),
          icon: const Icon(Icons.open_in_new),
        ),
      ),
    );
  }

  Future<void> _abrirMapa(double latitud, double longitud) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitud,$longitud',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la aplicación de mapas.'),
        ),
      );
    }
  }

  Widget _estado({
    required IconData icono,
    required String mensaje,
    Widget? accion,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(mensaje, textAlign: TextAlign.center),
          if (accion != null) ...[const SizedBox(height: 12), accion],
        ],
      ),
    );
  }
}
