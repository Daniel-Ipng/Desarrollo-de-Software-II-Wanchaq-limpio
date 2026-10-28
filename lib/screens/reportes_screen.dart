import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reporte.dart';
import '../repositories/reporte_repository.dart';
import '../theme/colores_app.dart';
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
  // ─── Paso 1: estado de la pantalla ─────────────────────────────────────────
  List<Reporte> _reportes = [];
  EstadoReporte? _filtro;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // ─── Paso 2: carga de reportes (misma lógica que la versión anterior) ──────
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

  // ─── Paso 3: estructura general (barra, cuerpo y botón flotante) ───────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis reportes',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: ColoresApp.tinta,
          ),
        ),
      ),
      body: RefreshIndicator(onRefresh: _cargar, child: _construirCuerpo()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irACrear,
        backgroundColor: ColoresApp.verde,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add),
        label: const Text(
          'Nuevo reporte',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ─── Paso 4: cuerpo según el estado (carga, error, vacío o lista) ──────────
  Widget _construirCuerpo() {
    if (_cargando) return _construirEsqueleto();

    if (_error != null) {
      return _centrado(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: ColoresApp.error),
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

    if (_reportes.isEmpty) {
      return _centrado(
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 112),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: ColoresApp.verdeClaro,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 48,
                  color: ColoresApp.verde,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Aún no tienes reportes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Presiona el botón para informar sobre un problema de residuos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ColoresApp.textoSecundario),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _irACrear,
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresApp.verde,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Crear mi primer reporte'),
              ),
            ],
          ),
        ),
      );
    }

    final reportesFiltrados = _filtro == null
        ? _reportes
        : _reportes.where((r) => r.estado == _filtro).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
      children: [
        // Filtros por estado, con contador
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
        const SizedBox(height: 14),
        if (reportesFiltrados.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
            child: Column(
              children: [
                const Icon(
                  Icons.filter_list_off,
                  size: 44,
                  color: ColoresApp.textoSuave,
                ),
                const SizedBox(height: 10),
                Text(
                  'No hay reportes en estado ${_filtro!.etiqueta.toLowerCase()}.',
                  textAlign: TextAlign.center,
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

  // ─── Paso 5: chip de filtro (ChoiceChip con contador) ──────────────────────
  Widget _filtroChip(String texto, EstadoReporte? estado) {
    final seleccionado = _filtro == estado;
    final colorTexto = seleccionado ? Colors.white : ColoresApp.textoSecundario;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        showCheckmark: false,
        selected: seleccionado,
        onSelected: (_) => setState(() => _filtro = estado),
        selectedColor: ColoresApp.verde,
        backgroundColor: Colors.white,
        shape: const StadiumBorder(),
        side: BorderSide(
          color: seleccionado ? ColoresApp.verde : ColoresApp.divisor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        // El texto del estado va solo en su propio Text (lo usan los tests);
        // el contador va en otro Text aparte.
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              texto,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: colorTexto,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${_contar(estado)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: seleccionado
                    ? Colors.white.withValues(alpha: 0.85)
                    : ColoresApp.textoSuave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cantidad de reportes por estado (null = todos).
  int _contar(EstadoReporte? estado) {
    if (estado == null) return _reportes.length;
    return _reportes.where((r) => r.estado == estado).length;
  }

  // ─── Paso 6: utilidades de diseño ──────────────────────────────────────────
  /// Centra un contenido y lo hace desplazable para que funcione el
  /// "tirar para actualizar" aunque no haya lista.
  Widget _centrado(Widget contenido) {
    return LayoutBuilder(
      builder: (context, restricciones) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: restricciones.maxHeight),
          child: Center(child: contenido),
        ),
      ),
    );
  }

  /// Esqueleto estático que se muestra mientras cargan los reportes.
  Widget _construirEsqueleto() {
    Widget bloque({double? ancho, required double alto, double radio = 20}) {
      return Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(
          color: ColoresApp.separadorBarra,
          borderRadius: BorderRadius.circular(radio),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
      children: [
        Row(
          children: [
            bloque(ancho: 80, alto: 38, radio: 19),
            const SizedBox(width: 8),
            bloque(ancho: 110, alto: 38, radio: 19),
            const SizedBox(width: 8),
            bloque(ancho: 110, alto: 38, radio: 19),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < 4; i++) ...[
          bloque(alto: 96),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ─── Paso 7: navegación ────────────────────────────────────────────────────
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ColoresApp.divisor),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _miniatura(),
                const SizedBox(width: 12),
                Expanded(child: _contenido()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Foto del reporte o, si no hay, un ícono sobre fondo verde.
  Widget _miniatura() {
    final fondoIcono = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ColoresApp.verde, ColoresApp.verdeOscuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(_iconoTipo(reporte.tipo), color: Colors.white, size: 30),
    );

    if (reporte.imagenUrl?.isNotEmpty != true) return fondoIcono;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        reporte.imagenUrl!,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fondoIcono,
      ),
    );
  }

  /// Título, zona, chip de estado y fecha con número de reporte.
  Widget _contenido() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                reporte.tipo.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: ColoresApp.textoSuave),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            const Icon(
              Icons.place_outlined,
              size: 15,
              color: ColoresApp.textoSuave,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                reporte.zona,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ColoresApp.textoSecundario,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChipEstado(estado: reporte.estado),
            Text(
              '${_fecha(reporte.creadoEn)} · #${reporte.id.toString().padLeft(4, '0')}',
              style: const TextStyle(
                color: ColoresApp.textoSuave,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _iconoTipo(TipoIncidencia tipo) => switch (tipo) {
    TipoIncidencia.residuosAcumulados => Icons.delete_sweep_outlined,
    TipoIncidencia.contenedorLleno => Icons.inventory_2_outlined,
    TipoIncidencia.faltaRecoleccion => Icons.local_shipping_outlined,
    TipoIncidencia.puntoIlegal => Icons.block,
    TipoIncidencia.otro => Icons.more_horiz,
  };

  /// Fecha corta en español: "12 oct" (agrega el año si no es el actual).
  String _fecha(DateTime fecha) {
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final base = '${fecha.day} ${meses[fecha.month - 1]}';
    return fecha.year == DateTime.now().year ? base : '$base ${fecha.year}';
  }
}