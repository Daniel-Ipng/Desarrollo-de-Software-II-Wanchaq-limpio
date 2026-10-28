import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reporte.dart';
import '../models/usuario.dart';
import '../repositories/reporte_repository.dart';
import '../repositories/usuario_repository.dart';
import '../theme/colores_app.dart';
import 'crear_reporte_screen.dart';

/// Pantalla de inicio del ciudadano autenticado.
///
/// Muestra un saludo con acción principal, el resumen de sus reportes,
/// el seguimiento de su último reporte y accesos rápidos.
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
  // ─── Paso 1: estado de la pantalla ─────────────────────────────────────────
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

  // ─── Paso 2: carga del resumen (misma lógica que la versión anterior) ──────
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

  // ─── Paso 3: construcción general de la pantalla ───────────────────────────
  @override
  Widget build(BuildContext context) {
    final primerNombre = widget.usuario.nombres.trim().split(' ').first;

    return RefreshIndicator(
      onRefresh: _cargarResumen,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _construirBanner(primerNombre),
          const SizedBox(height: 22),

          // Resumen de actividad
          _construirEncabezado(
            'Tu actividad',
            accion: 'Ver todo',
            alPulsar: widget.alIrAReportes,
          ),
          const SizedBox(height: 10),
          if (_cargando)
            _construirEsqueleto()
          else if (_errorCarga)
            _construirError()
          else ...[
            _construirResumen(),
            const SizedBox(height: 14),
            if (_recientes.isEmpty)
              _construirVacio()
            else ...[
              // Último reporte con su línea de seguimiento
              _construirSeguimiento(_recientes.first),
              // Reportes anteriores (si existen)
              if (_recientes.length > 1) ...[
                const SizedBox(height: 22),
                _construirEncabezado(
                  'Reportes recientes',
                  accion: 'Ver historial',
                  alPulsar: widget.alIrAReportes,
                ),
                const SizedBox(height: 10),
                ..._recientes.skip(1).map(_construirTarjetaReporte),
              ],
            ],
          ],

          // Accesos rápidos
          const SizedBox(height: 22),
          const Text(
            'Accesos rápidos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _construirAccesos(),

          // Mensaje de cierre
          const SizedBox(height: 22),
          _construirMensajeFinal(),
        ],
      ),
    );
  }

  // ─── Paso 4: banner con saludo y botón principal ───────────────────────────
  Widget _construirBanner(String primerNombre) {
    final zona = widget.usuario.zonaNombre;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ColoresApp.verde, Color(0xFF45A477)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: ColoresApp.verde.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '¡Hola, $primerNombre!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.eco, color: Colors.white, size: 28),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Construyamos juntos un Wanchaq más limpio.',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          if (zona != null && zona.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Tu zona: $zona',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Botón principal: ocupa todo el ancho y mide al menos 54 dp.
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _irACrearReporte,
              child: const SizedBox(
                height: 54,
                width: double.infinity,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: ColoresApp.verde, size: 24),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Reportar una incidencia',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ColoresApp.verde,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Paso 5: encabezado de sección reutilizable ────────────────────────────
  Widget _construirEncabezado(
    String titulo, {
    String? accion,
    VoidCallback? alPulsar,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (accion != null)
          TextButton(
            onPressed: alPulsar,
            child: Text(
              accion,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  // ─── Paso 6: tres contadores por estado ────────────────────────────────────
  Widget _construirResumen() {
    return Row(
      children: [
        Expanded(
          child: _tarjetaContador(
            '$_pendientes',
            'Pendientes',
            ColoresApp.advertencia,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _tarjetaContador(
            '$_enProceso',
            'En proceso',
            const Color(0xFF1D5FBF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _tarjetaContador('$_resueltos', 'Resueltos', ColoresApp.verde),
        ),
      ],
    );
  }

  Widget _tarjetaContador(String valor, String etiqueta, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: _decoracionTarjeta(),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Paso 7: tarjeta de seguimiento del último reporte ─────────────────────
  Widget _construirSeguimiento(Reporte reporte) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ColoresApp.divisor),
      ),
      child: InkWell(
        onTap: widget.alIrAReportes,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _filaReporte(reporte),
              const SizedBox(height: 16),
              _lineaProgreso(reporte.estado),
            ],
          ),
        ),
      ),
    );
  }

  /// Fila con ícono del tipo, título, zona + tiempo y chip de estado.
  Widget _filaReporte(Reporte reporte) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: ColoresApp.verdeClaro,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _iconoTipo(reporte.tipo),
            color: ColoresApp.verde,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reporte.tipo.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${reporte.zona} · ${_tiempoRelativo(reporte.creadoEn)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: ColoresApp.textoSuave,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _ChipEstadoInicio(estado: reporte.estado),
      ],
    );
  }

  /// Línea de progreso: Recibido → En proceso → Resuelto.
  Widget _lineaProgreso(EstadoReporte estado) {
    final enCurso = estado == EstadoReporte.enProceso;
    final resuelto = estado == EstadoReporte.resuelto;

    return Column(
      children: [
        Row(
          children: [
            _nodo(_NodoEstado.hecho),
            _tramo(activo: enCurso || resuelto),
            _nodo(
              resuelto
                  ? _NodoEstado.hecho
                  : enCurso
                  ? _NodoEstado.actual
                  : _NodoEstado.pendiente,
            ),
            _tramo(activo: resuelto),
            _nodo(resuelto ? _NodoEstado.hecho : _NodoEstado.pendiente),
          ],
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recibido', style: _estiloEtapa),
            Text('En proceso', style: _estiloEtapa),
            Text('Resuelto', style: _estiloEtapa),
          ],
        ),
      ],
    );
  }

  static const TextStyle _estiloEtapa = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: ColoresApp.textoSuave,
  );

  Widget _tramo({required bool activo}) {
    return Expanded(
      child: Container(
        height: 4,
        color: activo ? ColoresApp.verde : ColoresApp.divisor,
      ),
    );
  }

  Widget _nodo(_NodoEstado tipo) {
    switch (tipo) {
      case _NodoEstado.hecho:
        return _circuloNodo(ColoresApp.verde, Icons.check);
      case _NodoEstado.actual:
        return _circuloNodo(const Color(0xFF1D5FBF), Icons.autorenew);
      case _NodoEstado.pendiente:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: ColoresApp.divisor, width: 3),
          ),
        );
    }
  }

  Widget _circuloNodo(Color color, IconData icono) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icono, color: Colors.white, size: 14),
    );
  }

  // ─── Paso 8: tarjeta compacta para reportes anteriores ─────────────────────
  Widget _construirTarjetaReporte(Reporte reporte) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ColoresApp.divisor),
        ),
        child: InkWell(
          onTap: widget.alIrAReportes,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _filaReporte(reporte),
          ),
        ),
      ),
    );
  }

  // ─── Paso 9: estados de carga, error y vacío ───────────────────────────────
  /// Esqueleto estático mientras se carga el resumen.
  Widget _construirEsqueleto() {
    Widget bloque(double alto) => Container(
      height: alto,
      decoration: BoxDecoration(
        color: ColoresApp.separadorBarra,
        borderRadius: BorderRadius.circular(20),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: bloque(74)),
            const SizedBox(width: 10),
            Expanded(child: bloque(74)),
            const SizedBox(width: 10),
            Expanded(child: bloque(74)),
          ],
        ),
        const SizedBox(height: 14),
        bloque(120),
      ],
    );
  }

  Widget _construirError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No se pudo cargar tu resumen. Intenta nuevamente.'),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _cargarResumen,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _construirVacio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _decoracionTarjeta(),
      child: const Row(
        children: [
          Icon(Icons.inbox_outlined, color: ColoresApp.textoSuave),
          SizedBox(width: 12),
          Expanded(child: Text('Aún no tienes reportes recientes.')),
        ],
      ),
    );
  }

  // ─── Paso 10: accesos rápidos (4 columnas) ─────────────────────────────────
  Widget _construirAccesos() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _acceso('Reportar', Icons.photo_camera_outlined, _irACrearReporte),
        _acceso(
          'Mis reportes',
          Icons.assignment_outlined,
          widget.alIrAReportes,
        ),
        _acceso('Mapa', Icons.map_outlined, widget.alIrAMapa ?? () {}),
        _acceso('Perfil', Icons.person_outline, widget.alIrAPerfil ?? () {}),
      ],
    );
  }

  Widget _acceso(String etiqueta, IconData icono, VoidCallback accion) {
    // Material transparente: el InkWell necesita un ancestro Material.
    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: accion,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ColoresApp.divisor),
                  ),
                  child: Icon(icono, color: ColoresApp.verde, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Paso 11: mensaje de cierre ────────────────────────────────────────────
  Widget _construirMensajeFinal() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresApp.verdeClaro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.eco_outlined, color: ColoresApp.verdeOscuro),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tu participación ayuda a mejorar la gestión de residuos en Wanchaq.',
              style: TextStyle(color: ColoresApp.verdeOscuro),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Paso 12: utilidades ───────────────────────────────────────────────────
  /// Decoración común de las tarjetas blancas con borde suave.
  BoxDecoration _decoracionTarjeta() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ColoresApp.divisor),
    );
  }

  /// Ícono según el tipo de incidencia.
  IconData _iconoTipo(TipoIncidencia tipo) {
    return switch (tipo) {
      TipoIncidencia.residuosAcumulados => Icons.delete_sweep_outlined,
      TipoIncidencia.contenedorLleno => Icons.inventory_2_outlined,
      TipoIncidencia.faltaRecoleccion => Icons.local_shipping_outlined,
      TipoIncidencia.puntoIlegal => Icons.block,
      TipoIncidencia.otro => Icons.more_horiz,
    };
  }

  /// Convierte una fecha en un texto como "hace 2 días".
  String _tiempoRelativo(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inMinutes < 1) return 'hace un momento';
    if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
    if (diferencia.inDays < 30) {
      final dias = diferencia.inDays;
      return dias == 1 ? 'hace 1 día' : 'hace $dias días';
    }
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
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

/// Estados visuales de cada paso de la línea de progreso.
enum _NodoEstado { hecho, actual, pendiente }

/// Chip de estado con la paleta de EcoRutas (naranja, azul y verde).
class _ChipEstadoInicio extends StatelessWidget {
  final EstadoReporte estado;

  const _ChipEstadoInicio({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (color, fondo, icono) = switch (estado) {
      EstadoReporte.pendiente => (
        ColoresApp.advertencia,
        const Color(0xFFFEF0DC),
        Icons.schedule,
      ),
      EstadoReporte.enProceso => (
        const Color(0xFF1D5FBF),
        const Color(0xFFE3EDFB),
        Icons.autorenew,
      ),
      EstadoReporte.resuelto => (
        ColoresApp.verde,
        ColoresApp.verdeClaro,
        Icons.check,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            estado.etiqueta,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}