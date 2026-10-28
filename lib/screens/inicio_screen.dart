import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../models/reporte.dart';
import '../repositories/reporte_repository.dart';
import '../repositories/usuario_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crear_reporte_screen.dart';

/// Pantalla de inicio del ciudadano autenticado.
///
/// Muestra un saludo, un resumen de reportes y accesos directos.
class InicioScreen extends StatefulWidget {
  final Usuario usuario;
  final ReporteRepository repositorioReportes;
  final UsuarioRepository repositorioUsuario;
  final VoidCallback alCerrarSesion;
  final VoidCallback alIrAReportes;
  final VoidCallback? alIrAMapa;
  final VoidCallback? alIrAPerfil;

  const InicioScreen({
    super.key,
    required this.usuario,
    required this.repositorioReportes,
    required this.repositorioUsuario,
    required this.alCerrarSesion,
    required this.alIrAReportes,
    this.alIrAMapa,
    this.alIrAPerfil,
  });

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  int _totalReportes = 0;
  int _pendientes = 0;
  int _enProceso = 0;
  int _resueltos = 0;
  List<Reporte> _recientes = [];
  bool _cargando = true;
  bool _errorCarga = false;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    try {
      final reportes = await widget.repositorioReportes.listar();
      if (mounted) {
        setState(() {
          _totalReportes = reportes.length;
          _pendientes = reportes
              .where((r) => r.estado == EstadoReporte.pendiente)
              .length;
          _enProceso = reportes
              .where((r) => r.estado == EstadoReporte.enProceso)
              .length;
          _resueltos = reportes
              .where((r) => r.estado == EstadoReporte.resuelto)
              .length;
          _recientes = reportes.take(3).toList();
          _cargando = false;
          _errorCarga = false;
        });
      }
    } on AuthException catch (_) {
      widget.alCerrarSesion();
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _errorCarga = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final primerNombre = widget.usuario.nombres.split(' ').first;

    return RefreshIndicator(
      onRefresh: _cargarResumen,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colores.primary, const Color(0xFF45A477)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colores.primary.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.eco, color: Colors.white, size: 36),
                const SizedBox(height: 14),
                Text(
                  '¡Hola, $primerNombre!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Construyamos juntos un Wanchaq más limpio.',
                  style: TextStyle(color: Colors.white70),
                ),
                if (widget.usuario.zonaNombre?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tu zona: ${widget.usuario.zonaNombre}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colores.primary,
                  ),
                  onPressed: _irACrearReporte,
                  child: const Text('Reportar una incidencia'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tu actividad',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: widget.alIrAReportes,
                child: const Text('Ver reportes'),
              ),
            ],
          ),
          if (_cargando)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorCarga)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No se pudo cargar tu resumen. Intenta nuevamente.',
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _cargarResumen,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final ancho = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: ancho,
                      child: _tarjetaResumen(
                        context,
                        'Total reportes',
                        '$_totalReportes',
                        Icons.assignment_outlined,
                        colores.primary,
                      ),
                    ),
                    SizedBox(
                      width: ancho,
                      child: _tarjetaResumen(
                        context,
                        'Pendientes',
                        '$_pendientes',
                        Icons.schedule,
                        Colors.orange,
                      ),
                    ),
                    SizedBox(
                      width: ancho,
                      child: _tarjetaResumen(
                        context,
                        'En proceso',
                        '$_enProceso',
                        Icons.autorenew,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(
                      width: ancho,
                      child: _tarjetaResumen(
                        context,
                        'Resueltos',
                        '$_resueltos',
                        Icons.check_circle_outline,
                        colores.tertiary,
                      ),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Reportes recientes',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: widget.alIrAReportes,
                child: const Text('Ver historial'),
              ),
            ],
          ),
          if (!_cargando && !_errorCarga)
            if (_recientes.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.inbox_outlined),
                  title: Text('Aún no tienes reportes recientes.'),
                ),
              )
            else
              ..._recientes.map(
                (reporte) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.recycling_outlined),
                    title: Text(reporte.tipo.etiqueta),
                    subtitle: Text(reporte.zona),
                    trailing: Text(reporte.estado.etiqueta),
                    onTap: widget.alIrAReportes,
                  ),
                ),
              ),
          const SizedBox(height: 24),

          const Text(
            'Accesos rápidos',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final ancho = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _acceso(
                    context,
                    ancho,
                    'Reportar',
                    'Informa sobre un problema',
                    Icons.add_location_alt_outlined,
                    _irACrearReporte,
                  ),
                  _acceso(
                    context,
                    ancho,
                    'Mis reportes',
                    'Consulta su estado',
                    Icons.assignment_outlined,
                    widget.alIrAReportes,
                  ),
                  _acceso(
                    context,
                    ancho,
                    'Mapa de rutas',
                    'Ubicaciones disponibles',
                    Icons.map_outlined,
                    widget.alIrAMapa ?? () {},
                  ),
                  _acceso(
                    context,
                    ancho,
                    'Mi perfil',
                    'Tus datos de cuenta',
                    Icons.person_outline,
                    widget.alIrAPerfil ?? () {},
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Card(
            color: colores.surfaceContainerHighest,
            elevation: 0,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.eco_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu participación ayuda a mejorar la gestión de residuos en Wanchaq.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _acceso(
    BuildContext context,
    double ancho,
    String titulo,
    String subtitulo,
    IconData icono,
    VoidCallback accion,
  ) {
    final colores = Theme.of(context).colorScheme;
    return SizedBox(
      width: ancho,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: accion,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colores.primaryContainer,
                  child: Icon(icono, color: colores.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: colores.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaResumen(
    BuildContext context,
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 28),
            const SizedBox(height: 12),
            Text(titulo, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _irACrearReporte() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CrearReporteScreen(
          repositorio: widget.repositorioReportes,
          alCrear: _cargarResumen,
          zonaInicial: widget.usuario.zonaNombre,
          alExpirarSesion: widget.alCerrarSesion,
        ),
      ),
    );
  }
}
