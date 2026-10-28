import 'package:flutter/material.dart';

import '../models/reporte.dart';
import '../repositories/reporte_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/chip_estado.dart';
import 'crear_reporte_screen.dart';
import 'detalle_reporte_screen.dart';

/// Pantalla de listado de reportes del ciudadano autenticado.
class ReportesScreen extends StatefulWidget {
  final ReporteRepository repositorio;
  final String? zonaInicial;
  final VoidCallback? alExpirarSesion;

  const ReportesScreen({
    super.key,
    required this.repositorio,
    this.zonaInicial,
    this.alExpirarSesion,
  });

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  List<Reporte> _reportes = [];
  EstadoReporte? _filtro;
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
      final lista = await widget.repositorio.listar();
      if (mounted) {
        setState(() {
          _reportes = lista;
          _cargando = false;
        });
      }
    } on AuthException catch (_) {
      widget.alExpirarSesion?.call();
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar los reportes. Intenta nuevamente.';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes')),
      body: RefreshIndicator(onRefresh: _cargar, child: _construirCuerpo()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irACrear,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo reporte'),
      ),
    );
  }

  Widget _construirCuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final reportesFiltrados = _filtro == null
        ? _reportes
        : _reportes.where((r) => r.estado == _filtro).toList();

    if (_reportes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary.withAlpha(80),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aún no tienes reportes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Presiona el botón para informar sobre un problema de residuos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filtroChip('Todos', null),
              ...EstadoReporte.values.map(
                (estado) => _filtroChip(estado.etiqueta, estado),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (reportesFiltrados.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
            child: Column(
              children: [
                const Icon(Icons.filter_list_off, size: 44),
                const SizedBox(height: 10),
                Text(
                  'No hay reportes en estado ${_filtro!.etiqueta.toLowerCase()}.',
                ),
              ],
            ),
          )
        else
          ...reportesFiltrados.map(
            (reporte) => _TarjetaReporte(
              reporte: reporte,
              onTap: () => _irADetalle(reporte),
            ),
          ),
      ],
    );
  }

  Widget _filtroChip(String texto, EstadoReporte? estado) {
    final seleccionado = _filtro == estado;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: seleccionado,
        onSelected: (_) => setState(() => _filtro = estado),
      ),
    );
  }

  void _irACrear() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CrearReporteScreen(
          repositorio: widget.repositorio,
          alCrear: _cargar,
          zonaInicial: widget.zonaInicial,
          alExpirarSesion: widget.alExpirarSesion,
        ),
      ),
    );
  }

  void _irADetalle(Reporte reporte) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleReporteScreen(
          reporteId: reporte.id,
          repositorio: widget.repositorio,
          alExpirarSesion: widget.alExpirarSesion,
        ),
      ),
    );
  }
}

// ─── Tarjeta individual de reporte ──────────────────────────────────────────

class _TarjetaReporte extends StatelessWidget {
  final Reporte reporte;
  final VoidCallback onTap;

  const _TarjetaReporte({required this.reporte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reporte.imagenUrl?.isNotEmpty == true)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    reporte.imagenUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _iconoReporte(colores),
                  ),
                )
              else
                _iconoReporte(colores),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reporte.tipo.etiqueta,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 15,
                          color: colores.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            reporte.zona,
                            style: TextStyle(
                              color: colores.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChipEstado(estado: reporte.estado),
                        Text(
                          _fecha(reporte.creadoEn),
                          style: TextStyle(
                            color: colores.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconoReporte(ColorScheme colores) => CircleAvatar(
    radius: 24,
    backgroundColor: colores.primaryContainer,
    child: Icon(_iconoTipo(reporte.tipo), color: colores.primary),
  );

  IconData _iconoTipo(TipoIncidencia tipo) => switch (tipo) {
    TipoIncidencia.residuosAcumulados => Icons.delete_sweep_outlined,
    TipoIncidencia.contenedorLleno => Icons.delete_outline,
    TipoIncidencia.faltaRecoleccion => Icons.local_shipping_outlined,
    TipoIncidencia.puntoIlegal => Icons.warning_amber_outlined,
    TipoIncidencia.otro => Icons.more_horiz,
  };

  String _fecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }
}
