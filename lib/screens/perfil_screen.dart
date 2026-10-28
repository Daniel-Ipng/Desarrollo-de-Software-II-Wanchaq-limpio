import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/usuario.dart';
import '../models/zona.dart';
import '../repositories/usuario_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerfilScreen extends StatefulWidget {
  final UsuarioRepository repositorio;
  final VoidCallback alExpirarSesion;
  final ValueChanged<Usuario>? alActualizarPerfil;

  const PerfilScreen({
    super.key,
    required this.repositorio,
    required this.alExpirarSesion,
    this.alActualizarPerfil,
  });

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  Usuario? _usuario;
  List<Zona> _zonas = [];
  Zona? _zonaSeleccionada;
  String? _errorCarga;
  String? _errorZonas;
  String? _errorGuardar;
  String? _mensajeUbicacion;
  bool _cargando = true;
  bool _editando = false;
  bool _guardando = false;
  bool _cargandoZonas = false;
  bool _obteniendoGps = false;
  double? _latitud;
  double? _longitud;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidosCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final usuario = await widget.repositorio.obtenerPerfil();
      if (!mounted) return;
      setState(() {
        _usuario = usuario;
        _nombreCtrl.text = usuario.nombres;
        _apellidosCtrl.text = usuario.apellidos;
        _telefonoCtrl.text = usuario.telefono ?? '';
        _direccionCtrl.text = usuario.direccion ?? '';
        _latitud = usuario.latitudDomicilio;
        _longitud = usuario.longitudDomicilio;
        _zonaSeleccionada = usuario.zonaId == null
            ? null
            : Zona(
                id: usuario.zonaId!,
                nombre: usuario.zonaNombre ?? 'Zona actual',
              );
        _cargando = false;
      });
    } on AuthException catch (_) {
      widget.alExpirarSesion();
      return;
    } catch (_) {
      _establecerErrorCarga();
    }
  }

  void _establecerErrorCarga() {
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _errorCarga = 'No se pudo cargar tu perfil. Intenta nuevamente.';
    });
  }

  Future<void> _iniciarEdicion() async {
    setState(() {
      _editando = true;
      _cargandoZonas = true;
      _errorZonas = null;
      _errorGuardar = null;
    });
    try {
      final zonas = await widget.repositorio.listarZonasActivas();
      if (!mounted) return;
      final zonaActualId = _usuario?.zonaId;
      Zona? seleccion;
      for (final zona in zonas) {
        if (zona.id == zonaActualId) {
          seleccion = zona;
          break;
        }
      }
      setState(() {
        _zonas = zonas;
        _zonaSeleccionada = seleccion ?? (zonas.isEmpty ? null : zonas.first);
        _cargandoZonas = false;
        _errorZonas = zonas.isEmpty
            ? 'No hay zonas activas disponibles.'
            : null;
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
        throw const _GpsError('Activa los servicios de ubicación.');
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw const _GpsError(
          'Permiso denegado. Puedes conservar la dirección manual.',
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
        _mensajeUbicacion = 'Ubicación GPS actualizada.';
      });
    } on _GpsError catch (error) {
      if (mounted) setState(() => _mensajeUbicacion = error.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _mensajeUbicacion = 'No se pudo obtener el GPS.');
      }
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate() ||
        _zonaSeleccionada == null ||
        _guardando) {
      return;
    }
    setState(() {
      _guardando = true;
      _errorGuardar = null;
    });
    try {
      final usuario = await widget.repositorio.actualizarPerfil(
        nombres: _nombreCtrl.text.trim(),
        apellidos: _apellidosCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isEmpty
            ? null
            : _telefonoCtrl.text.trim(),
        zonaId: _zonaSeleccionada!.id,
        direccion: _direccionCtrl.text.trim(),
        latitudDomicilio: _latitud,
        longitudDomicilio: _longitud,
      );
      if (!mounted) return;
      setState(() {
        _usuario = usuario;
        _editando = false;
        _guardando = false;
      });
      widget.alActualizarPerfil?.call(usuario);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
    } on AuthException catch (_) {
      widget.alExpirarSesion();
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _errorGuardar = 'No se pudo guardar el perfil. Intenta nuevamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCarga != null) {
      return _estadoError(context);
    }
    return _editando ? _formularioEdicion(context) : _vistaPerfil(context);
  }

  Widget _estadoError(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 16),
          Text(_errorCarga!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _cargarPerfil,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );

  Widget _vistaPerfil(BuildContext context) {
    final usuario = _usuario!;
    final colores = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _iniciarEdicion,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar perfil'),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colores.primary, const Color(0xFF45A477)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                child: Text(
                  _iniciales(usuario),
                  style: TextStyle(
                    color: colores.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombreCompleto,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      usuario.correo,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (usuario.zonaNombre != null)
                      Text(
                        usuario.zonaNombre!,
                        style: const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _dato('Nombre', usuario.nombres, Icons.person_outline),
        _dato('Apellidos', _opcional(usuario.apellidos), Icons.people_outline),
        _dato('DNI', _opcional(usuario.dni), Icons.badge_outlined),
        _dato('Correo', usuario.correo, Icons.email_outlined),
        _dato('Teléfono', _opcional(usuario.telefono), Icons.phone_outlined),
        _dato(
          'Zona de residencia',
          usuario.zonaNombre ?? 'No registrada',
          Icons.location_city_outlined,
        ),
        _dato(
          'Dirección',
          usuario.direccion?.isNotEmpty == true
              ? usuario.direccion!
              : 'No registrada',
          Icons.home_outlined,
        ),
        if (usuario.latitudDomicilio != null &&
            usuario.longitudDomicilio != null)
          _dato(
            'Ubicación del domicilio',
            '${usuario.latitudDomicilio!.toStringAsFixed(6)}, '
                '${usuario.longitudDomicilio!.toStringAsFixed(6)}',
            Icons.my_location,
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _mostrarCambioContrasena(context),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Cambiar contraseña'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.alExpirarSesion,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }

  String _iniciales(Usuario usuario) {
    final partes = usuario.nombreCompleto
        .split(' ')
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  Future<void> _mostrarCambioContrasena(BuildContext context) async {
    final actual = TextEditingController();
    final nueva = TextEditingController();
    final confirmacion = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var visible = false;
    var guardando = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: actual,
                    obscureText: !visible,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña actual',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Ingresa tu contraseña actual'
                        : null,
                  ),
                  TextFormField(
                    controller: nueva,
                    obscureText: !visible,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialogState(() => visible = !visible),
                        icon: Icon(
                          visible ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 8) {
                        return 'Usa al menos 8 caracteres';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: confirmacion,
                    obscureText: !visible,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar nueva contraseña',
                    ),
                    validator: (value) => value != nueva.text
                        ? 'Las contraseñas no coinciden'
                        : null,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        guardando = true;
                        error = null;
                      });
                      try {
                        await widget.repositorio.cambiarContrasena(
                          actual: actual.text,
                          nueva: nueva.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contraseña actualizada.'),
                          ),
                        );
                      } on AuthException catch (exception) {
                        setDialogState(() {
                          guardando = false;
                          error = exception.message.contains('Invalid')
                              ? 'La contraseña actual no es correcta.'
                              : 'No se pudo actualizar la contraseña.';
                        });
                      } catch (_) {
                        setDialogState(() {
                          guardando = false;
                          error = 'No se pudo actualizar la contraseña.';
                        });
                      }
                    },
              child: guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    actual.dispose();
    nueva.dispose();
    confirmacion.dispose();
  }

  Widget _formularioEdicion(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Editar perfil',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _campo(_nombreCtrl, 'Nombre', maxLength: 100),
          _campo(_apellidosCtrl, 'Apellidos', maxLength: 100),
          TextFormField(
            controller: _telefonoCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Teléfono (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_cargandoZonas)
            const Center(child: CircularProgressIndicator())
          else if (_zonas.isEmpty)
            Column(
              children: [
                Text(_errorZonas ?? 'No hay zonas activas.'),
                TextButton.icon(
                  onPressed: _iniciarEdicion,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            )
          else
            DropdownButtonFormField<Zona>(
              initialValue: _zonaSeleccionada,
              decoration: const InputDecoration(
                labelText: 'Zona de residencia',
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
          const SizedBox(height: 12),
          TextFormField(
            controller: _direccionCtrl,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            validator: _validarRequerido,
            decoration: const InputDecoration(
              labelText: 'Dirección o referencia',
              border: OutlineInputBorder(),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.my_location, color: colores.primary),
              title: const Text('Coordenadas del domicilio'),
              subtitle: Text(
                _latitud == null || _longitud == null
                    ? 'No disponibles'
                    : '${_latitud!.toStringAsFixed(6)}, '
                          '${_longitud!.toStringAsFixed(6)}',
              ),
              trailing: IconButton(
                tooltip: 'Obtener ubicación GPS',
                onPressed: _obteniendoGps ? null : _obtenerUbicacion,
                icon: _obteniendoGps
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ),
          ),
          if (_mensajeUbicacion != null) Text(_mensajeUbicacion!),
          if (_errorGuardar != null)
            Text(_errorGuardar!, style: TextStyle(color: colores.error)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _guardando || _zonaSeleccionada == null
                ? null
                : _guardarCambios,
            icon: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_guardando ? 'Guardando...' : 'Guardar cambios'),
          ),
          TextButton(
            onPressed: _guardando
                ? null
                : () => setState(() {
                    _editando = false;
                    _errorGuardar = null;
                  }),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _campo(
    TextEditingController controller,
    String label, {
    required int maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        validator: _validarRequerido,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String? _validarRequerido(String? value) =>
      value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio.'
      : null;

  String _opcional(String? value) =>
      value == null || value.isEmpty ? 'No registrado' : value;

  Widget _dato(String etiqueta, String valor, IconData icono) => Card(
    child: ListTile(
      leading: Icon(icono, color: Theme.of(context).colorScheme.primary),
      title: Text(etiqueta),
      subtitle: Text(valor),
    ),
  );
}

class _GpsError implements Exception {
  final String mensaje;
  const _GpsError(this.mensaje);
}
