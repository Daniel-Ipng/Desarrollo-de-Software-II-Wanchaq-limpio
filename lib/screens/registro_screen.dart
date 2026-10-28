import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/zona.dart';
import '../repositories/usuario_repository.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  List<Zona> _zonas = [];
  Zona? _zonaSeleccionada;
  int _paso = 0;
  double? _latitud;
  double? _longitud;
  bool _cargandoZonas = true;
  bool _cargando = false;
  bool _obteniendoGps = false;
  bool _verContrasena = false;
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
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _contrasenaCtrl.dispose();
    _confirmarCtrl.dispose();
    _direccionCtrl.dispose();
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
        _zonaSeleccionada = zonas.isEmpty ? null : zonas.first;
        _cargandoZonas = false;
        _errorZonas = null;
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
          'Permiso denegado. Puedes continuar sin coordenadas y escribir una referencia.',
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
    } on _UbicacionError catch (error) {
      if (mounted) setState(() => _mensajeUbicacion = error.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => _mensajeUbicacion = 'No se pudo obtener el GPS. Puedes indicar la dirección manualmente.',
        );
      }
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  Future<void> _continuar() async {
    if (_paso == 0 && !_formKey.currentState!.validate()) return;
    if (_paso == 1) {
      if (_cargandoZonas) return;
      if (_zonas.isEmpty || _zonaSeleccionada == null) {
        setState(() => _errorZonas = 'No hay zonas activas disponibles.');
        return;
      }
    }
    if (_paso == 2 &&
        (_direccionCtrl.text.trim().isEmpty ||
            _direccionCtrl.text.trim().length > 500)) {
      setState(
        () => _mensajeUbicacion =
            'Escribe una dirección o referencia de hasta 500 caracteres.',
      );
      return;
    }
    if (_paso < 3) {
      setState(() {
        _paso++;
        _error = null;
      });
      return;
    }
    await _registrar();
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
      widget.alRegistrarse();
    } else {
      setState(() {
        _cargando = false;
        _error = resultado.error ?? 'No se pudo crear la cuenta.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta ciudadana')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paso ${_paso + 1} de 4'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: (_paso + 1) / 4),
                      const SizedBox(height: 16),
                      Text(
                        const [
                          'Datos personales',
                          'Zona',
                          'Domicilio',
                          'Revisión',
                        ][_paso],
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _contenidoPaso(context, key: ValueKey(_paso)),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _aviso(
                            _error!,
                            colores.errorContainer,
                            colores.onErrorContainer,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                  child: Row(
                    children: [
                      if (_paso > 0)
                        OutlinedButton(
                          onPressed: _cargando
                              ? null
                              : () => setState(() {
                                  _paso--;
                                  _error = null;
                                }),
                          child: const Text('Anterior'),
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
                                _paso == 3
                                    ? Icons.person_add
                                    : Icons.arrow_forward,
                              ),
                        label: Text(
                          _cargando
                              ? 'Creando cuenta...'
                              : _paso == 3
                              ? 'Confirmar registro'
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

  Widget _contenidoPaso(BuildContext context, {required Key key}) {
    switch (_paso) {
      case 0:
        return _datosPersonales(context, key);
      case 1:
        return _seleccionarZona(context, key);
      case 2:
        return _direccion(context, key);
      default:
        return _resumen(context, key);
    }
  }

  Widget _datosPersonales(BuildContext context, Key key) => Column(
    key: key,
    children: [
      _campo(_nombresCtrl, 'Nombres', validator: _requerido, maxLength: 100),
      _campo(
        _apellidosCtrl,
        'Apellidos',
        validator: _requerido,
        maxLength: 100,
      ),
      _campo(
        _dniCtrl,
        'DNI',
        keyboardType: TextInputType.number,
        maxLength: 8,
        validator: (value) =>
            value == null || !RegExp(r'^\d{8}$').hasMatch(value)
            ? 'El DNI debe tener ocho dígitos.'
            : null,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(8),
        ],
      ),
      _campo(
        _correoCtrl,
        'Correo electrónico',
        keyboardType: TextInputType.emailAddress,
        maxLength: 150,
        validator: (value) {
          if (value == null ||
              !RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(value.trim())) {
            return 'Escribe un correo válido.';
          }
          return null;
        },
      ),
      _campo(
        _telefonoCtrl,
        'Teléfono (opcional)',
        keyboardType: TextInputType.phone,
        maxLength: 20,
      ),
      TextFormField(
        controller: _contrasenaCtrl,
        obscureText: !_verContrasena,
        validator: (value) => value == null || value.length < 8
            ? 'Mínimo ocho caracteres.'
            : null,
        decoration: InputDecoration(
          labelText: 'Contraseña',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _verContrasena = !_verContrasena),
            icon: Icon(
              _verContrasena ? Icons.visibility_off : Icons.visibility,
            ),
          ),
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _confirmarCtrl,
        obscureText: true,
        validator: (value) => value != _contrasenaCtrl.text
            ? 'Las contraseñas no coinciden.'
            : null,
        decoration: const InputDecoration(
          labelText: 'Confirmar contraseña',
          prefixIcon: Icon(Icons.lock_outline),
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );

  Widget _seleccionarZona(BuildContext context, Key key) {
    if (_cargandoZonas) {
      return const Center(
        key: ValueKey('zones-loading'),
        child: Padding(
          padding: EdgeInsets.all(36),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_errorZonas != null || _zonas.isEmpty) {
      return Column(
        key: key,
        children: [
          _aviso(
            _errorZonas ?? 'No hay zonas activas disponibles.',
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _cargarZonas,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar carga de zonas'),
          ),
        ],
      );
    }
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecciona una zona activa de residencia.'),
        const SizedBox(height: 14),
        DropdownButtonFormField<Zona>(
          initialValue: _zonaSeleccionada,
          decoration: const InputDecoration(
            labelText: 'Zona de residencia',
            prefixIcon: Icon(Icons.location_city_outlined),
            border: OutlineInputBorder(),
          ),
          items: _zonas
              .map(
                (zona) =>
                    DropdownMenuItem(value: zona, child: Text(zona.nombre)),
              )
              .toList(),
          onChanged: (zona) => setState(() => _zonaSeleccionada = zona),
        ),
        if (_zonaSeleccionada?.descripcion?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Text(_zonaSeleccionada!.descripcion!),
        ],
      ],
    );
  }

  Widget _direccion(BuildContext context, Key key) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextFormField(
        controller: _direccionCtrl,
        maxLength: 500,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Dirección o referencia',
          hintText: 'Escribe una referencia de tu domicilio',
          prefixIcon: Icon(Icons.home_outlined),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ubicación GPS del domicilio',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_latitud != null && _longitud != null)
                Text(
                  'Latitud ${_latitud!.toStringAsFixed(6)}\n'
                  'Longitud ${_longitud!.toStringAsFixed(6)}',
                )
              else
                const Text('Aún no se han obtenido coordenadas.'),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _obteniendoGps ? null : _obtenerUbicacion,
                icon: _obteniendoGps
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Usar ubicación actual'),
              ),
              if (_mensajeUbicacion != null) ...[
                const SizedBox(height: 8),
                Text(_mensajeUbicacion!),
              ],
            ],
          ),
        ),
      ),
      _aviso(
        'No hay un proveedor de mapas configurado. Puedes guardar la dirección manualmente; las coordenadas solo se enviarán si el dispositivo las obtiene.',
        Theme.of(context).colorScheme.surfaceContainerHighest,
        Theme.of(context).colorScheme.onSurface,
      ),
    ],
  );

  Widget _resumen(BuildContext context, Key key) {
    final colores = Theme.of(context).colorScheme;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resumenDato('Nombre', '${_nombresCtrl.text} ${_apellidosCtrl.text}'),
        _resumenDato('DNI', _dniCtrl.text),
        _resumenDato('Correo', _correoCtrl.text),
        _resumenDato(
          'Teléfono',
          _telefonoCtrl.text.trim().isEmpty
              ? 'No indicado'
              : _telefonoCtrl.text,
        ),
        _resumenDato('Zona', _zonaSeleccionada?.nombre ?? ''),
        _resumenDato('Dirección', _direccionCtrl.text.trim()),
        _resumenDato(
          'Coordenadas',
          _latitud == null || _longitud == null
              ? 'No disponibles'
              : '${_latitud!.toStringAsFixed(6)}, ${_longitud!.toStringAsFixed(6)}',
        ),
        const SizedBox(height: 8),
        _aviso(
          'La cuenta se creará como ciudadano. Supabase gestionará la contraseña de forma segura.',
          colores.primaryContainer,
          colores.onPrimaryContainer,
        ),
      ],
    );
  }

  Widget _campo(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        validator: validator,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String? _requerido(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio.'
      : null;

  Widget _resumenDato(String label, String value) => Card(
    child: ListTile(dense: true, title: Text(label), subtitle: Text(value)),
  );

  Widget _aviso(String message, Color background, Color foreground) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message, style: TextStyle(color: foreground)),
      );
}

class _UbicacionError implements Exception {
  final String mensaje;
  const _UbicacionError(this.mensaje);
}
