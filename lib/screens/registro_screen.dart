import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/zona.dart';
import '../repositories/usuario_repository.dart';
import '../theme/colores_app.dart';
import '../utils/validadores.dart';
import '../widgets/campo_texto.dart';

/// Registro de ciudadanos en 3 pasos: Datos, Domicilio y Revisión.
class RegistroScreen extends StatefulWidget {
  final UsuarioRepository repositorio;
  final VoidCallback alRegistrarse;

  const RegistroScreen({
    super.key,
    required this.repositorio,
    required this.alRegistrarse,
  });

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  static const _etiquetasPasos = ['Datos', 'Domicilio', 'Revisión'];
  static const _ultimoPaso = 2;
  static const _ubicacionWanchaq = LatLng(-13.53195, -71.96746);

  final _formKey = GlobalKey<FormState>();
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _mapController = MapController();

  List<Zona> _zonas = [];
  Zona? _zonaSeleccionada;
  int _paso = 0;
  double? _latitud;
  double? _longitud;
  bool _cargandoZonas = true;
  bool _cargando = false;
  bool _obteniendoGps = false;
  bool _aceptaPolitica = false;
  String? _error;
  String? _errorZonas;
  String? _mensajeUbicacion;

  @override
  void initState() {
    super.initState();
    _cargarZonas();
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _dniCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    _confirmarCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  LatLng? get _coordenadasSeleccionadas {
    if (_latitud == null || _longitud == null) return null;
    return LatLng(_latitud!, _longitud!);
  }

  // ─── Lógica ────────────────────────────────────────────────────────────────

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
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _cargandoZonas = false;
        _errorZonas = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoZonas = false;
        _errorZonas = 'No se pudieron cargar las zonas.';
      });
    }
  }

  Future<void> _obtenerUbicacion() async {
    setState(() {
      _obteniendoGps = true;
      _mensajeUbicacion = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _UbicacionError('Activa los servicios de ubicación.');
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw const _UbicacionError(
          'Permiso denegado. Puedes continuar y marcar tu domicilio en el mapa.',
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
        _mensajeUbicacion = 'Ubicación actual obtenida del dispositivo.';
      });
      _mapController.move(LatLng(posicion.latitude, posicion.longitude), 16);
    } on _UbicacionError catch (error) {
      if (mounted) setState(() => _mensajeUbicacion = error.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => _mensajeUbicacion =
              'No se pudo obtener el GPS. Marca tu domicilio en el mapa.',
        );
      }
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  Future<void> _continuar() async {
    if (_paso < _ultimoPaso) {
      if (!_formKey.currentState!.validate()) return;
      if (_paso == 1 && _zonaSeleccionada == null) {
        setState(() => _errorZonas ??= 'Selecciona tu zona de residencia.');
        return;
      }
      setState(() {
        _paso++;
        _error = null;
      });
      return;
    }
    if (_aceptaPolitica) await _registrar();
  }

  void _retroceder() {
    if (_paso == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _paso--;
      _error = null;
    });
  }

  Future<void> _registrar() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    final resultado = await widget.repositorio.registrar(
      nombres: _nombresCtrl.text.trim(),
      apellidos: _apellidosCtrl.text.trim(),
      dni: _dniCtrl.text.trim(),
      correo: _correoCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      contrasena: _contrasenaCtrl.text,
      zonaId: _zonaSeleccionada!.id,
      direccion: _direccionCtrl.text.trim(),
      latitudDomicilio: _latitud,
      longitudDomicilio: _longitud,
    );
    if (!mounted) return;
    if (resultado.exito) {
      setState(() => _cargando = false);
      Navigator.of(context).pop();
      widget.alRegistrarse();
    } else {
      setState(() {
        _cargando = false;
        _error = resultado.error ?? 'No se pudo crear la cuenta.';
      });
    }
  }

  // ─── Interfaz ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paso == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _retroceder();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back),
            onPressed: _cargando ? null : _retroceder,
          ),
          title: const Text('Crear cuenta ciudadana'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  _IndicadorPasos(
                    pasoActual: _paso,
                    etiquetas: _etiquetasPasos,
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _contenidoPaso(key: ValueKey(_paso)),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            _Aviso(
                              mensaje: _error!,
                              fondo: ColoresApp.errorFondo,
                              texto: ColoresApp.errorTexto,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _barraAcciones(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenidoPaso({required Key key}) {
    switch (_paso) {
      case 0:
        return _pasoDatos(key);
      case 1:
        return _pasoDomicilio(key);
      default:
        return _pasoRevision(key);
    }
  }

  Widget _barraAcciones() {
    final esUltimo = _paso == _ultimoPaso;
    final puedeContinuar = !_cargando && (!esUltimo || _aceptaPolitica);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColoresApp.separadorBarra)),
      ),
      child: Row(
        children: [
          if (_paso > 0) ...[
            OutlinedButton(
              onPressed: _cargando ? null : _retroceder,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                foregroundColor: ColoresApp.verde,
                side: const BorderSide(color: ColoresApp.verde, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Anterior',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(
              onPressed: puedeContinuar ? _continuar : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: ColoresApp.verde,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      esUltimo ? 'Confirmar registro' : 'Continuar',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Paso 1: datos personales ──────────────────────────────────────────────

  Widget _pasoDatos(Key key) {
    return AutofillGroup(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CampoTexto(
                  controlador: _nombresCtrl,
                  etiqueta: 'Nombres',
                  pista: 'Ej. Mario',
                  maxLongitud: 100,
                  capitalizacion: TextCapitalization.words,
                  accionTeclado: TextInputAction.next,
                  pistasAutocompletado: const [AutofillHints.givenName],
                  validador: validarRequerido,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CampoTexto(
                  controlador: _apellidosCtrl,
                  etiqueta: 'Apellidos',
                  pista: 'Ej. Ccahuana',
                  maxLongitud: 100,
                  capitalizacion: TextCapitalization.words,
                  accionTeclado: TextInputAction.next,
                  pistasAutocompletado: const [AutofillHints.familyName],
                  validador: validarRequerido,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CampoTexto(
                  controlador: _dniCtrl,
                  etiqueta: 'DNI',
                  pista: '8 dígitos',
                  tipoTeclado: TextInputType.number,
                  maxLongitud: 8,
                  accionTeclado: TextInputAction.next,
                  formateadores: [FilteringTextInputFormatter.digitsOnly],
                  validador: validarDni,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CampoTexto(
                  controlador: _telefonoCtrl,
                  etiqueta: 'Teléfono (opcional)',
                  pista: 'Ej. 987654321',
                  tipoTeclado: TextInputType.phone,
                  maxLongitud: 9,
                  accionTeclado: TextInputAction.next,
                  pistasAutocompletado: const [AutofillHints.telephoneNumberNational],
                  formateadores: [FilteringTextInputFormatter.digitsOnly],
                  validador: validarTelefonoOpcional,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CampoTexto(
            controlador: _correoCtrl,
            etiqueta: 'Correo electrónico',
            pista: 'tucorreo@gmail.com',
            tipoTeclado: TextInputType.emailAddress,
            maxLongitud: 150,
            accionTeclado: TextInputAction.next,
            pistasAutocompletado: const [AutofillHints.email],
            validador: validarCorreo,
          ),
          const SizedBox(height: 14),
          CampoTexto(
            controlador: _contrasenaCtrl,
            etiqueta: 'Contraseña',
            pista: 'Mínimo 8 caracteres',
            esContrasena: true,
            accionTeclado: TextInputAction.next,
            pistasAutocompletado: const [AutofillHints.newPassword],
            alCambiar: (_) => setState(() {}),
            validador: validarContrasenaNueva,
          ),
          _MedidorFortaleza(contrasena: _contrasenaCtrl.text),
          const SizedBox(height: 14),
          CampoTexto(
            controlador: _confirmarCtrl,
            etiqueta: 'Confirmar contraseña',
            pista: 'Repite tu contraseña',
            esContrasena: true,
            accionTeclado: TextInputAction.done,
            validador: (valor) => valor != _contrasenaCtrl.text
                ? 'Las contraseñas no coinciden.'
                : null,
          ),
        ],
      ),
    );
  }

  // ─── Paso 2: domicilio ─────────────────────────────────────────────────────

  Widget _pasoDomicilio(Key key) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _selectorZona(),
        const SizedBox(height: 14),
        CampoTexto(
          controlador: _direccionCtrl,
          etiqueta: 'Dirección o referencia',
          pista: 'Ej. Urb. Magisterio C-12, frente al parque',
          tipoTeclado: TextInputType.multiline,
          maxLineas: 3,
          maxLongitud: 500,
          validador: validarDireccion,
        ),
        const SizedBox(height: 16),
        const Text(
          'Marca tu domicilio en el mapa',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColoresApp.etiqueta,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _coordenadasSeleccionadas ?? _ubicacionWanchaq,
                initialZoom: _coordenadasSeleccionadas == null ? 13 : 16,
                onTap: (_, punto) {
                  setState(() {
                    _latitud = punto.latitude;
                    _longitud = punto.longitude;
                    _mensajeUbicacion = 'Ubicación marcada en el mapa.';
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mi_app',
                ),
                if (_coordenadasSeleccionadas != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _coordenadasSeleccionadas!,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFFC2410C),
                          size: 44,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Mapa © OpenStreetMap contributors',
          style: TextStyle(fontSize: 11, color: ColoresApp.textoSecundario),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _obteniendoGps ? null : _obtenerUbicacion,
          icon: _obteniendoGps
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location, size: 20),
          label: const Text('Usar mi ubicación actual'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: ColoresApp.verde,
            side: const BorderSide(color: ColoresApp.verde, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _latitud == null || _longitud == null
              ? 'La ubicación en el mapa es opcional.'
              : '${_mensajeUbicacion ?? 'Ubicación marcada.'}\n'
                    '${_latitud!.toStringAsFixed(6)}, ${_longitud!.toStringAsFixed(6)}',
          style: const TextStyle(
            fontSize: 13,
            color: ColoresApp.textoSecundario,
          ),
        ),
        if (_latitud == null && _mensajeUbicacion != null) ...[
          const SizedBox(height: 4),
          Text(
            _mensajeUbicacion!,
            style: const TextStyle(fontSize: 13, color: ColoresApp.errorTexto),
          ),
        ],
      ],
    );
  }

  Widget _selectorZona() {
    if (_cargandoZonas) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_zonas.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Aviso(
            mensaje: _errorZonas ?? 'No hay zonas activas disponibles.',
            fondo: ColoresApp.errorFondo,
            texto: ColoresApp.errorTexto,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cargarZonas,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar carga de zonas'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Zona de residencia',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColoresApp.etiqueta,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<Zona>(
          initialValue: _zonaSeleccionada,
          isExpanded: true,
          hint: const Text('Selecciona tu zona'),
          decoration: CampoTexto.decoracion(),
          validator: (zona) => zona == null ? 'Selecciona tu zona.' : null,
          items: _zonas
              .map((zona) => DropdownMenuItem(value: zona, child: Text(zona.nombre)))
              .toList(),
          onChanged: (zona) => setState(() {
            _zonaSeleccionada = zona;
            _errorZonas = null;
          }),
        ),
        if (_zonaSeleccionada?.descripcion?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            _zonaSeleccionada!.descripcion!,
            style: const TextStyle(
              fontSize: 13,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ],
      ],
    );
  }

  // ─── Paso 3: revisión ──────────────────────────────────────────────────────

  Widget _pasoRevision(Key key) {
    final telefono = _telefonoCtrl.text.trim();
    final coordenadas = _latitud == null || _longitud == null
        ? 'No marcadas'
        : '${_latitud!.toStringAsFixed(6)}, ${_longitud!.toStringAsFixed(6)}';

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _FilaResumen(
                etiqueta: 'Nombre',
                valor: '${_nombresCtrl.text.trim()} ${_apellidosCtrl.text.trim()}',
              ),
              _FilaResumen(etiqueta: 'DNI', valor: _dniCtrl.text),
              _FilaResumen(
                etiqueta: 'Teléfono',
                valor: telefono.isEmpty ? 'No indicado' : telefono,
              ),
              _FilaResumen(etiqueta: 'Correo', valor: _correoCtrl.text.trim()),
              _FilaResumen(etiqueta: 'Zona', valor: _zonaSeleccionada?.nombre ?? ''),
              _FilaResumen(
                etiqueta: 'Dirección',
                valor: _direccionCtrl.text.trim(),
              ),
              _FilaResumen(
                etiqueta: 'Coordenadas',
                valor: coordenadas,
                ultima: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _aceptaPolitica,
          onChanged: (valor) => setState(() => _aceptaPolitica = valor ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: ColoresApp.verde,
          title: const Text.rich(
            TextSpan(
              text: 'Acepto la ',
              children: [
                TextSpan(
                  text: 'política de privacidad',
                  style: TextStyle(
                    color: ColoresApp.verde,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: ' y el tratamiento de mis datos personales.'),
              ],
            ),
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        const SizedBox(height: 8),
        const _Aviso(
          mensaje:
              'Tu cuenta se creará como ciudadano. Podrás reportar incidencias y ver los horarios de tu zona.',
          fondo: ColoresApp.verdeClaro,
          texto: ColoresApp.verdeOscuro,
        ),
      ],
    );
  }
}

// ─── Widgets privados ────────────────────────────────────────────────────────

class _IndicadorPasos extends StatelessWidget {
  final int pasoActual;
  final List<String> etiquetas;

  const _IndicadorPasos({required this.pasoActual, required this.etiquetas});

  @override
  Widget build(BuildContext context) {
    final elementos = <Widget>[];
    for (var i = 0; i < etiquetas.length; i++) {
      elementos.add(_paso(i));
      if (i < etiquetas.length - 1) {
        elementos.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(top: 13),
              color: i < pasoActual ? ColoresApp.verde : ColoresApp.divisor,
            ),
          ),
        );
      }
    }
    return Semantics(
      label: 'Paso ${pasoActual + 1} de ${etiquetas.length}: '
          '${etiquetas[pasoActual]}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: elementos,
        ),
      ),
    );
  }

  Widget _paso(int indice) {
    final completado = indice < pasoActual;
    final actual = indice == pasoActual;
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completado || actual ? ColoresApp.verde : Colors.white,
              border: completado || actual
                  ? null
                  : Border.all(color: ColoresApp.pasoPendiente, width: 1.5),
            ),
            child: completado
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${indice + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: actual ? Colors.white : ColoresApp.textoSecundario,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            etiquetas[indice],
            style: TextStyle(
              fontSize: 12,
              fontWeight: actual ? FontWeight.w700 : FontWeight.w500,
              color: indice <= pasoActual
                  ? ColoresApp.tinta
                  : ColoresApp.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedidorFortaleza extends StatelessWidget {
  final String contrasena;

  const _MedidorFortaleza({required this.contrasena});

  @override
  Widget build(BuildContext context) {
    if (contrasena.isEmpty) return const SizedBox.shrink();

    final fortaleza = calcularFortaleza(contrasena);
    final (color, colorTexto, texto) = switch (fortaleza) {
      FortalezaContrasena.debil => (
        ColoresApp.error,
        ColoresApp.errorTexto,
        'Débil',
      ),
      FortalezaContrasena.media => (
        ColoresApp.advertencia,
        ColoresApp.advertenciaTexto,
        'Media',
      ),
      FortalezaContrasena.fuerte => (
        ColoresApp.verde,
        ColoresApp.verdeOscuro,
        'Fuerte',
      ),
    };
    final tramosActivos = fortaleza.index + 1;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: i < tramosActivos ? color : ColoresApp.divisor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorTexto,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool ultima;

  const _FilaResumen({
    required this.etiqueta,
    required this.valor,
    this.ultima = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : const Border(bottom: BorderSide(color: ColoresApp.separadorBarra)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 12,
              color: ColoresApp.textoSecundario,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String mensaje;
  final Color fondo;
  final Color texto;

  const _Aviso({
    required this.mensaje,
    required this.fondo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mensaje,
        style: TextStyle(fontSize: 13, height: 1.4, color: texto),
      ),
    );
  }
}

class _UbicacionError implements Exception {
  final String mensaje;
  const _UbicacionError(this.mensaje);
}