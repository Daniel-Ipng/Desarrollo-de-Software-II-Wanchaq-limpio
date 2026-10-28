import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reporte.dart';
import '../models/usuario.dart';
import '../repositories/reporte_repository.dart';
import '../repositories/usuario_repository.dart';
import '../repositories/administracion_repository.dart';
import 'administracion_screen.dart';
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
  ResumenAdministrativo? _resumen;

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
      await Future.wait([_cargarReportes(), _cargarResumen()]);
    } on AuthException catch (_) {
      widget.alCerrarSesion();
    } catch (_) {
      _mostrarError(
        'No se pudo validar el acceso. Comprueba tu conexión e inténtalo de nuevo.',
      );
    }
  }

  Future<void> _cargarResumen() async {
    try {
      final resumen = await AdministracionRepository().cargarResumen();
      if (mounted) setState(() => _resumen = resumen);
    } catch (_) {
      // Los indicadores de incidencias siguen siendo útiles si las tablas
      // operativas aún no se han aplicado en Supabase.
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
            onPressed: _verificando
                ? null
                : () async {
                    await _cargarReportes();
                    await _cargarResumen();
                  },
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
                      descripcion: 'Usuarios, roles y estado de las cuentas.',
                      onTap: () => _abrirAdministracion(pestana: 0),
                      contador: _resumen?.usuarios,
                    ),
                    _modulo(
                      context,
                      icono: Icons.local_shipping_outlined,
                      titulo: 'Flota y operación',
                      descripcion: 'Camiones, zonas, rutas y tipos de residuos.',
                      onTap: () => _abrirAdministracion(pestana: 1),
                      contador: _resumen?.camiones,
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
        _indicador('Incidencias', _reportes.length, Icons.assignment, colores.primary),
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
        if (_resumen != null)
          _indicador(
            'Usuarios',
            _resumen!.usuarios,
            Icons.people_outline,
            colores.secondary,
          ),
        if (_resumen != null)
          _indicador(
            'Camiones',
            _resumen!.camiones,
            Icons.local_shipping_outlined,
            Colors.indigo,
          ),
        if (_resumen != null)
          _indicador(
            'Zonas',
            _resumen!.zonas,
            Icons.location_on_outlined,
            Colors.teal,
          ),
        if (_resumen != null)
          _indicador(
            'Recolecciones',
            _resumen!.recolecciones,
            Icons.recycling_outlined,
            Colors.brown,
          ),
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

  void _abrirAdministracion({required int pestana}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdministracionScreen(
          repositorio: AdministracionRepository(),
          reportesRepositorio: widget.reportesRepositorio,
          pestanaInicial: pestana,
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
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reportes = [...widget.reportes];
    _cargarReportes();
  }

  Future<void> _cargarReportes() async {
    if (mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final reportes = await widget.repositorio
          .listarTodosParaAdministrador();
      if (!mounted) return;
      setState(() {
        _reportes = reportes;
        _cargando = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = _mensajeError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error =
            'No se pudieron cargar los reportes. Revisa la sesión del administrador y las políticas RLS.';
      });
    }
  }

  String _mensajeError(PostgrestException error) {
    if (error.code == '42501') {
      return 'Supabase rechazó la consulta. Ejecuta schema_supabase.sql y verifica que tu perfil tenga rol admin activo.';
    }
    if (error.code == '42P01') {
      return 'La tabla reportes no existe en Supabase. Ejecuta schema_supabase.sql.';
    }
    return 'No se pudieron cargar los reportes (${error.code}).';
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtro == null
        ? _reportes
        : _reportes.where((r) => r.estado == _filtro).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Incidencias')),
      body: RefreshIndicator(
        onRefresh: _cargarReportes,
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
            if (_cargando)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 44),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _cargarReportes,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (filtrados.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No hay reportes para este filtro. Si esperabas ver '
                    'registros existentes, actualiza y verifica las políticas '
                    'administrativas en Supabase.',
                    textAlign: TextAlign.center,
                  ),
                ),
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _DetalleIncidenciaAdminScreen(reporte: reporte),
          ),
        ),
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
      await Future.wait([_cargarReportes(), widget.alActualizar()]);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la incidencia.')),
      );
    }
  }
}

class _DetalleIncidenciaAdminScreen extends StatelessWidget {
  final Reporte reporte;

  const _DetalleIncidenciaAdminScreen({required this.reporte});

  @override
  Widget build(BuildContext context) {
    final tieneImagen = reporte.imagenUrl?.isNotEmpty == true;
    final tieneCoordenadas = reporte.latitud != null &&
        reporte.longitud != null &&
        reporte.latitud!.isFinite &&
        reporte.longitud!.isFinite;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reporte #${reporte.id}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Icon(_iconoTipo(reporte.tipo)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reporte.tipo.etiqueta,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ChipEstado(estado: reporte.estado),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _dato('Descripción', reporte.descripcion, Icons.notes_outlined),
          _dato('Zona o dirección', reporte.zona, Icons.place_outlined),
          _dato(
            'Fecha de registro',
            _fecha(reporte.creadoEn.toLocal()),
            Icons.schedule_outlined,
          ),
          _dato('Ciudadano', reporte.ciudadanoId, Icons.person_outline),
          if (tieneCoordenadas) ...[
            _dato(
              'Coordenadas GPS',
              '${reporte.latitud!.toStringAsFixed(6)}, '
                  '${reporte.longitud!.toStringAsFixed(6)}',
              Icons.my_location_outlined,
            ),
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      reporte.latitud!,
                      reporte.longitud!,
                    ),
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ecorutas.wanchaq',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(reporte.latitud!, reporte.longitud!),
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 42,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Mapa © OpenStreetMap contributors',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Evidencia fotográfica',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (tieneImagen)
            GestureDetector(
              onTap: () => _mostrarImagen(context, reporte.imagenUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  reporte.imagenUrl!,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _sinImagen(
                    'No se pudo cargar la imagen asociada.',
                  ),
                ),
              ),
            )
          else
            _sinImagen('Este reporte no tiene una imagen asociada.'),
        ],
      ),
    );
  }

  Widget _dato(String titulo, String valor, IconData icono) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icono),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(valor),
      ),
    );
  }

  Widget _sinImagen(String mensaje) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(mensaje, textAlign: TextAlign.center),
    );
  }

  void _mostrarImagen(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  String _fecha(DateTime fecha) {
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  IconData _iconoTipo(TipoIncidencia tipo) => switch (tipo) {
    TipoIncidencia.residuosAcumulados => Icons.delete_sweep_outlined,
    TipoIncidencia.contenedorLleno => Icons.delete_outline,
    TipoIncidencia.faltaRecoleccion => Icons.local_shipping_outlined,
    TipoIncidencia.puntoIlegal => Icons.warning_amber_outlined,
    TipoIncidencia.otro => Icons.assignment_outlined,
  };
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
