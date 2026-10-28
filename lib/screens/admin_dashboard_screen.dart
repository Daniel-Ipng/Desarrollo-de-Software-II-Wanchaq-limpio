import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reporte.dart';
import '../models/usuario.dart';
import '../repositories/reporte_repository.dart';
import '../repositories/usuario_repository.dart';
import '../widgets/chip_estado.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Usuario usuario;
  final UsuarioRepository repositorio;
  final ReporteRepository reportesRepositorio;
  final VoidCallback alCerrarSesion;

  const AdminDashboardScreen({
    super.key,
    required this.usuario,
    required this.repositorio,
    required this.reportesRepositorio,
    required this.alCerrarSesion,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _verificando = true;
  String? _error;
  List<Reporte> _reportes = [];

  @override
  void initState() {
    super.initState();
    _verificarAcceso();
  }

  Future<void> _verificarAcceso() async {
    setState(() {
      _verificando = true;
      _error = null;
    });
    try {
      await widget.repositorio.verificarAccesoAdministrador();
      if (!mounted) return;
      setState(() => _verificando = false);
      await _cargarReportes();
    } on AuthException catch (_) {
      widget.alCerrarSesion();
    } catch (_) {
      _mostrarError(
        'No se pudo validar el acceso. Comprueba tu conexión e inténtalo de nuevo.',
      );
    }
  }

  Future<void> _cargarReportes() async {
    setState(() {
      _error = null;
    });
    try {
      final reportes = await widget.reportesRepositorio
          .listarTodosParaAdministrador();
      if (!mounted) return;
      setState(() {
        _reportes = reportes;
      });
    } on AuthException catch (_) {
      widget.alCerrarSesion();
    } catch (_) {
      _mostrarError('No se pudieron cargar las incidencias.');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    setState(() {
      _verificando = false;
      _error = mensaje;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel administrativo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar datos',
            onPressed: _verificando ? null : _cargarReportes,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: widget.alCerrarSesion,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: _verificando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _estadoError()
            : RefreshIndicator(
                onRefresh: _cargarReportes,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _encabezado(colores),
                    const SizedBox(height: 22),
                    _indicadores(colores),
                    const SizedBox(height: 26),
                    const Text(
                      'Gestión del servicio',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _modulo(
                      context,
                      icono: Icons.assignment_outlined,
                      titulo: 'Incidencias',
                      descripcion: 'Revisa reportes y actualiza su estado.',
                      onTap: _abrirIncidencias,
                      contador: _reportes.length,
                    ),
                    _modulo(
                      context,
                      icono: Icons.map_outlined,
                      titulo: 'Mapa de incidencias',
                      descripcion: 'Ubica los reportes que tienen coordenadas GPS.',
                      onTap: _abrirMapa,
                    ),
                    _modulo(
                      context,
                      icono: Icons.people_outline,
                      titulo: 'Ciudadanos',
                      descripcion:
                          'La consulta de perfiles requiere habilitar su vista administrativa.',
                      onTap: _mostrarModuloPendiente,
                    ),
                    const SizedBox(height: 10),
                    Card(
                      color: colores.surfaceContainerHighest,
                      elevation: 0,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user_outlined),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'El acceso y los cambios de estado se validan en Supabase mediante las políticas de administrador.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _estadoError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _verificarAcceso,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(ColorScheme colores) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colores.primary, colores.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            color: Colors.white,
            size: 38,
          ),
          const SizedBox(height: 18),
          const Text(
            'Resumen de operaciones',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.usuario.nombreCompleto,
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            widget.usuario.correo,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _indicadores(ColorScheme colores) {
    final pendientes = _reportes
        .where((reporte) => reporte.estado == EstadoReporte.pendiente)
        .length;
    final enProceso = _reportes
        .where((reporte) => reporte.estado == EstadoReporte.enProceso)
        .length;
    final resueltos = _reportes
        .where((reporte) => reporte.estado == EstadoReporte.resuelto)
        .length;

    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 650 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        _indicador('Total', _reportes.length, Icons.assignment, colores.primary),
        _indicador(
          'Pendientes',
          pendientes,
          Icons.schedule,
          Colors.orange.shade700,
        ),
        _indicador(
          'En proceso',
          enProceso,
          Icons.autorenew,
          Colors.blue.shade700,
        ),
        _indicador('Resueltos', resueltos, Icons.check_circle, Colors.green),
      ],
    );
  }

  Widget _indicador(String titulo, int valor, IconData icono, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icono, color: color),
            Text(
              '$valor',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(titulo),
          ],
        ),
      ),
    );
  }

  Widget _modulo(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
    int? contador,
  }) {
    final colores = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colores.primaryContainer,
          child: Icon(icono, color: colores.primary),
        ),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(descripcion),
        trailing: contador == null
            ? const Icon(Icons.chevron_right)
            : Badge(
                label: Text('$contador'),
                child: const Icon(Icons.chevron_right),
              ),
        onTap: onTap,
      ),
    );
  }

  void _abrirIncidencias() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _IncidenciasAdminScreen(
          reportes: _reportes,
          repositorio: widget.reportesRepositorio,
          alActualizar: _cargarReportes,
        ),
      ),
    );
  }

  void _abrirMapa() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MapaAdminScreen(reportes: _reportes),
      ),
    );
  }

  void _mostrarModuloPendiente() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La gestión de perfiles todavía no está habilitada en este proyecto.',
        ),
      ),
    );
  }
}

class _IncidenciasAdminScreen extends StatefulWidget {
  final List<Reporte> reportes;
  final ReporteRepository repositorio;
  final Future<void> Function() alActualizar;

  const _IncidenciasAdminScreen({
    required this.reportes,
    required this.repositorio,
    required this.alActualizar,
  });

  @override
  State<_IncidenciasAdminScreen> createState() => _IncidenciasAdminScreenState();
}

class _IncidenciasAdminScreenState extends State<_IncidenciasAdminScreen> {
  late List<Reporte> _reportes;
  EstadoReporte? _filtro;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _reportes = [...widget.reportes];
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtro == null
        ? _reportes
        : _reportes.where((r) => r.estado == _filtro).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Incidencias')),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.alActualizar();
          if (!context.mounted) return;
          Navigator.of(context).pop();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filtroChip('Todas', null),
                  ...EstadoReporte.values.map(
                    (estado) => _filtroChip(estado.etiqueta, estado),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (filtrados.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No hay incidencias en este estado.')),
              )
            else
              ...filtrados.map(_tarjeta),
          ],
        ),
      ),
    );
  }

  Widget _filtroChip(String texto, EstadoReporte? estado) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: _filtro == estado,
        onSelected: (_) => setState(() => _filtro = estado),
      ),
    );
  }

  Widget _tarjeta(Reporte reporte) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            reporte.imagenUrl == null
                ? Icons.assignment_outlined
                : Icons.photo_camera_outlined,
          ),
        ),
        title: Text(reporte.tipo.etiqueta),
        subtitle: Text(
          '${reporte.zona}\n${reporte.descripcion}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: _guardando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<EstadoReporte>(
                tooltip: 'Cambiar estado',
                initialValue: reporte.estado,
                onSelected: (estado) => _cambiarEstado(reporte, estado),
                itemBuilder: (_) => EstadoReporte.values
                    .map(
                      (estado) => PopupMenuItem(
                        value: estado,
                        child: Text(estado.etiqueta),
                      ),
                    )
                    .toList(),
                child: ChipEstado(estado: reporte.estado),
              ),
      ),
    );
  }

  Future<void> _cambiarEstado(Reporte reporte, EstadoReporte estado) async {
    if (estado == reporte.estado) return;
    setState(() => _guardando = true);
    try {
      final actualizado = await widget.repositorio
          .actualizarEstadoAdministrador(id: reporte.id, estado: estado);
      if (!mounted) return;
      setState(() {
        final indice = _reportes.indexWhere((item) => item.id == reporte.id);
        if (indice >= 0) _reportes[indice] = actualizado;
        _guardando = false;
      });
      await widget.alActualizar();
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la incidencia.')),
      );
    }
  }
}

class _MapaAdminScreen extends StatelessWidget {
  final List<Reporte> reportes;

  const _MapaAdminScreen({required this.reportes});

  @override
  Widget build(BuildContext context) {
    final ubicados = reportes.where(_tieneCoordenadas).toList();
    final centro = ubicados.isEmpty
        ? const LatLng(-13.53195, -71.96746)
        : LatLng(ubicados.first.latitud!, ubicados.first.longitud!);

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de incidencias')),
      body: ubicados.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay incidencias con coordenadas GPS para mostrar.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : FlutterMap(
              options: MapOptions(initialCenter: centro, initialZoom: 13),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ecorutas.wanchaq',
                ),
                MarkerLayer(
                  markers: ubicados
                      .map(
                        (reporte) => Marker(
                          point: LatLng(
                            reporte.latitud!,
                            reporte.longitud!,
                          ),
                          width: 46,
                          height: 46,
                          child: Tooltip(
                            message:
                                '${reporte.tipo.etiqueta} - ${reporte.zona}',
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
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
}
