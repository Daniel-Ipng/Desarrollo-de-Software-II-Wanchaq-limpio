import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/reporte.dart';
import '../models/zona.dart';
import '../repositories/reporte_repository.dart';

class CrearReporteScreen extends StatefulWidget {
  final ReporteRepository repositorio;
  final VoidCallback? alCrear;
  final String? zonaInicial;
  final VoidCallback? alExpirarSesion;

  const CrearReporteScreen({
    super.key,
    required this.repositorio,
    this.alCrear,
    this.zonaInicial,
    this.alExpirarSesion,
  });

  @override
  State<CrearReporteScreen> createState() => _CrearReporteScreenState();
}

class _CrearReporteScreenState extends State<CrearReporteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();
  final _zonaCtrl = TextEditingController();
  final _mapController = MapController();
  final _imagePicker = ImagePicker();

  static const _pasos = ['Problema', 'Ubicación', 'Detalles', 'Foto'];
  TipoIncidencia _tipo = TipoIncidencia.residuosAcumulados;
  int _paso = 0;
  double? _latitud;
  double? _longitud;
  Uint8List? _fotoBytes;
  String? _nombreFoto;
  bool _obteniendoUbicacion = false;
  bool _cargando = false;
  bool _cargandoZonas = true;
  String? _errorGlobal;
  String? _mensajeUbicacion;
  String? _errorZonas;
  List<Zona> _zonas = [];

  @override
  void initState() {
    super.initState();
    _zonaCtrl.text = widget.zonaInicial ?? '';
    _cargarZonas();
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _zonaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarZonas() async {
    setState(() {
      _cargandoZonas = true;
      _errorZonas = null;
    });
    try {
      final zonas = await widget.repositorio.listarZonasActivas();
      if (!mounted) return;
      setState(() {
        _zonas = zonas;
        _cargandoZonas = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoZonas = false;
        _errorZonas = 'No se pudieron cargar las zonas activas.';
      });
    }
  }

  Future<void> _obtenerUbicacion() async {
    setState(() {
      _obteniendoUbicacion = true;
      _mensajeUbicacion = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _ErrorUbicacion(
          'Activa los servicios de ubicación o escribe la zona manualmente.',
        );
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw const _ErrorUbicacion(
          'No se concedió el permiso. Puedes continuar indicando la zona manualmente.',
        );
      }

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitud = posicion.latitude;
        _longitud = posicion.longitude;
        _mensajeUbicacion = 'Ubicación GPS actualizada';
      });
    } on _ErrorUbicacion catch (error) {
      if (mounted) setState(() => _mensajeUbicacion = error.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() {
          _mensajeUbicacion =
              'No se pudo obtener el GPS. Puedes indicar la zona manualmente.';
        });
      }
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  Future<void> _seleccionarFoto(ImageSource origen) async {
    try {
      final imagen = await _imagePicker.pickImage(
        source: origen,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (imagen == null) return;
      final bytes = await imagen.readAsBytes();
      if (!mounted) return;
      setState(() {
        _fotoBytes = bytes;
        _nombreFoto = imagen.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la imagen seleccionada.'),
        ),
      );
    }
  }

  Future<void> _continuar() async {
    if (_paso == 1 && _zonaCtrl.text.trim().isEmpty) {
      setState(
        () => _mensajeUbicacion = 'Indica una zona o dirección para continuar.',
      );
      return;
    }
    if (_paso == 2 && !_formKey.currentState!.validate()) return;
    if (_paso < _pasos.length - 1) {
      setState(() {
        _paso++;
        _errorGlobal = null;
      });
      return;
    }
    await _enviar();
  }

  Future<void> _enviar() async {
    setState(() {
      _cargando = true;
      _errorGlobal = null;
    });

    final fechaEnvioDispositivo = DateTime.now();
    final resultado = await widget.repositorio.crear(
      tipo: _tipo,
      descripcion: _descripcionCtrl.text.trim(),
      zona: _zonaCtrl.text.trim(),
      latitud: _latitud,
      longitud: _longitud,
      imagen: _fotoBytes,
      nombreImagen: _nombreFoto,
    );

    if (!mounted) return;

    if (resultado.exito) {
      widget.alCrear?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reporte enviado${_fotoBytes == null ? '' : ' con foto'}. '
            'La fecha oficial es la registrada por el servidor '
            '(${_formatearFecha(fechaEnvioDispositivo)} como referencia local).',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      if (resultado.codigoHttp == 401) {
        widget.alExpirarSesion?.call();
        return;
      }
      setState(() {
        _cargando = false;
        _errorGlobal = resultado.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo reporte'), centerTitle: false),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: _barraProgreso(context),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _contenidoPaso(context, key: ValueKey(_paso)),
                        ),
                        if (_errorGlobal != null) ...[
                          const SizedBox(height: 16),
                          _mensaje(
                            _errorGlobal!,
                            colores.errorContainer,
                            colores.onErrorContainer,
                            Icons.error_outline,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: Row(
                    children: [
                      if (_paso > 0)
                        OutlinedButton.icon(
                          onPressed: _cargando
                              ? null
                              : () => setState(() => _paso--),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Atrás'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _cargando ? null : _continuar,
                        icon: _cargando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _paso == _pasos.length - 1
                                    ? Icons.send_outlined
                                    : Icons.arrow_forward,
                              ),
                        label: Text(
                          _cargando
                              ? 'Enviando...'
                              : _paso == _pasos.length - 1
                              ? 'Enviar reporte'
                              : 'Continuar',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _barraProgreso(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paso ${_paso + 1} de ${_pasos.length}',
          style: TextStyle(color: colores.primary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(_pasos.length, (indice) {
            return Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: indice == 3 ? 0 : 6),
                decoration: BoxDecoration(
                  color: indice <= _paso
                      ? colores.primary
                      : colores.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          _pasos[_paso],
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _contenidoPaso(BuildContext context, {required Key key}) {
    return switch (_paso) {
      0 => _pasoTipo(context, key),
      1 => _pasoUbicacion(context, key),
      2 => _pasoDetalles(context, key),
      _ => _pasoFoto(context, key),
    };
  }

  Widget _pasoTipo(BuildContext context, Key key) {
    final colores = Theme.of(context).colorScheme;
    const iconos = {
      TipoIncidencia.residuosAcumulados: Icons.delete_sweep_outlined,
      TipoIncidencia.contenedorLleno: Icons.delete_outline,
      TipoIncidencia.faltaRecoleccion: Icons.local_shipping_outlined,
      TipoIncidencia.puntoIlegal: Icons.warning_amber_outlined,
      TipoIncidencia.otro: Icons.more_horiz,
    };
    return RadioGroup<TipoIncidencia>(
      groupValue: _tipo,
      onChanged: (valor) {
        if (valor != null) setState(() => _tipo = valor);
      },
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Qué problema deseas reportar?'),
          const SizedBox(height: 14),
          ...TipoIncidencia.values.map((tipo) {
            final seleccionado = _tipo == tipo;
            return Card(
              color: seleccionado ? colores.primaryContainer : Colors.white,
              child: RadioListTile<TipoIncidencia>(
                value: tipo,
                secondary: Icon(iconos[tipo], color: colores.primary),
                title: Text(tipo.etiqueta),
                activeColor: colores.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _pasoUbicacion(BuildContext context, Key key) {
    final colores = Theme.of(context).colorScheme;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Usa tu ubicación actual o escribe una zona de referencia.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.my_location, color: colores.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Ubicación del dispositivo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar ubicación GPS',
                      onPressed: _obteniendoUbicacion
                          ? null
                          : _obtenerUbicacion,
                      icon: _obteniendoUbicacion
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_latitud != null && _longitud != null) ...[
                  const SizedBox(height: 12),
                  Text('Latitud  ${_latitud!.toStringAsFixed(6)}'),
                  Text('Longitud  ${_longitud!.toStringAsFixed(6)}'),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    'El GPS es opcional. No se han capturado coordenadas.',
                    style: TextStyle(color: colores.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _obteniendoUbicacion ? null : _obtenerUbicacion,
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Obtener GPS'),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_mensajeUbicacion != null) ...[
          const SizedBox(height: 8),
          Text(
            _mensajeUbicacion!,
            style: TextStyle(color: colores.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _zonaCtrl,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Zona o dirección aproximada',
            hintText: 'Escribe una referencia que ayude a ubicar el problema',
            prefixIcon: Icon(Icons.place_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (valor) => valor == null || valor.trim().isEmpty
              ? 'Indica una zona o dirección'
              : null,
        ),
        if (_cargandoZonas)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (_zonas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String>(
              initialValue: _zonas.any((zona) => zona.nombre == _zonaCtrl.text)
                  ? _zonaCtrl.text
                  : null,
              decoration: const InputDecoration(
                labelText: 'Seleccionar una zona activa (opcional)',
                prefixIcon: Icon(Icons.location_city_outlined),
                border: OutlineInputBorder(),
              ),
              items: _zonas
                  .map(
                    (zona) => DropdownMenuItem(
                      value: zona.nombre,
                      child: Text(zona.nombre),
                    ),
                  )
                  .toList(),
              onChanged: (nombre) {
                if (nombre != null) _zonaCtrl.text = nombre;
              },
            ),
          )
        else if (_errorZonas != null)
          Row(
            children: [
              Expanded(child: Text(_errorZonas!)),
              IconButton(
                tooltip: 'Reintentar carga de zonas',
                onPressed: _cargarZonas,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        const SizedBox(height: 4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Mapa de ubicación',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_latitud != null && _longitud != null)
                      IconButton(
                        tooltip: 'Centrar en la ubicación actual',
                        onPressed: () {
                          _mapController.move(
                            LatLng(_latitud!, _longitud!),
                            15,
                          );
                        },
                        icon: const Icon(Icons.center_focus_strong_outlined),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _latitud != null && _longitud != null
                            ? LatLng(_latitud!, _longitud!)
                            : const LatLng(-13.53195, -71.96746),
                        initialZoom: 13,
                        onTap: (_, punto) {
                          setState(() {
                            _latitud = punto.latitude;
                            _longitud = punto.longitude;
                            _mensajeUbicacion =
                                'Ubicación seleccionada en el mapa.';
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.mi_app',
                        ),
                        if (_latitud != null && _longitud != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_latitud!, _longitud!),
                                width: 28,
                                height: 28,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pasoDetalles(BuildContext context, Key key) {
    final ahora = DateTime.now();
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _descripcionCtrl,
          minLines: 5,
          maxLines: 8,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Descripción del problema',
            hintText: 'Describe lo que observaste...',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (valor) {
            if (valor == null || valor.trim().length < 10) {
              return 'Escribe al menos 10 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _mensaje(
          'Hora de este dispositivo: ${_formatearFecha(ahora)}. La fecha oficial del reporte la asigna el servidor.',
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.onPrimaryContainer,
          Icons.schedule,
        ),
      ],
    );
  }

  Widget _pasoFoto(BuildContext context, Key key) {
    final colores = Theme.of(context).colorScheme;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Adjunta una imagen para documentar la incidencia.'),
        const SizedBox(height: 16),
        if (_fotoBytes != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  _fotoBytes!,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Quitar imagen',
                  onPressed: () => setState(() {
                    _fotoBytes = null;
                    _nombreFoto = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
              ),
              if (_nombreFoto != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _nombreFoto!,
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
          )
        else
          Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colores.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colores.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 42,
                  color: colores.primary,
                ),
                const SizedBox(height: 8),
                const Text('Aún no hay una imagen seleccionada'),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _seleccionarFoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Tomar foto'),
            ),
            OutlinedButton.icon(
              onPressed: () => _seleccionarFoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galería'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _mensaje(
          _fotoBytes == null
              ? 'Puedes continuar sin foto o adjuntar una imagen desde la cámara o galería.'
              : 'La imagen se almacenará de forma segura en ImageKit al enviar el reporte.',
          colores.tertiaryContainer,
          colores.onTertiaryContainer,
          Icons.info_outline,
        ),
      ],
    );
  }

  Widget _mensaje(String texto, Color fondo, Color textoColor, IconData icono) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: textoColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: TextStyle(color: textoColor)),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} $hora:$minuto';
  }
}

class _ErrorUbicacion implements Exception {
  final String mensaje;
  const _ErrorUbicacion(this.mensaje);
}
