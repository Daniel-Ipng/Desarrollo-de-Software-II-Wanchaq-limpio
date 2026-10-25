import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../config.dart';
import '../models.dart';
import '../utils.dart';

class NuevaIncidenciaScreen extends StatefulWidget {
  const NuevaIncidenciaScreen({super.key});
  @override
  State<NuevaIncidenciaScreen> createState() => _NuevaIncidenciaScreenState();
}

class _NuevaIncidenciaScreenState extends State<NuevaIncidenciaScreen> {
  final _form = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _direccion = TextEditingController();

  List<Zona> _zonas = [];
  String? _tipo;
  String? _zona;
  File? _foto;
  Position? _pos;
  bool _usarUbicacion = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarZonas();
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _cargarZonas() async {
    try {
      final z = (await Api.zonas()).where((e) => e.estado == 'activa').toList();
      if (!mounted) return;
      final mia = Api.sesion.value?.zona;
      setState(() {
        _zonas = z;
        if (mia != null && z.any((e) => e.nombre == mia)) _zona = mia;
      });
    } on ApiException catch (e) {
      if (mounted) mensaje(context, e.message);
    }
  }

  Future<void> _elegirFoto(ImageSource origen) async {
    try {
      final x = await ImagePicker().pickImage(source: origen, maxWidth: 1600, imageQuality: 80);
      if (x != null && mounted) setState(() => _foto = File(x.path));
    } catch (_) {
      if (mounted) mensaje(context, 'No se pudo abrir la cámara o la galería.');
    }
  }

  Future<void> _alternarUbicacion(bool v) async {
    if (!v) {
      setState(() {
        _usarUbicacion = false;
        _pos = null;
      });
      return;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) mensaje(context, 'Activa el GPS de tu celular.');
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        if (mounted) mensaje(context, 'Permiso de ubicación denegado.');
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _usarUbicacion = true;
        _pos = p;
      });
    } catch (_) {
      if (mounted) mensaje(context, 'No se pudo obtener tu ubicación.');
    }
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await Api.crearIncidencia(
        tipo: _tipo!,
        descripcion: _descripcion.text.trim(),
        zona: _zona!,
        direccion: _direccion.text.trim(),
        lat: _pos?.latitude,
        lng: _pos?.longitude,
        foto: _foto,
      );
      if (!mounted) return;
      mensaje(context, 'Tu incidencia fue registrada correctamente.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) mensaje(context, e.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar incidencia')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(children: [
              DropdownButtonFormField<String>(
                value: _tipo,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Tipo de incidencia', border: OutlineInputBorder()),
                items: Config.tiposIncidencia
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v),
                validator: (v) => v == null ? 'Selecciona un tipo.' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _zona,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Zona', border: OutlineInputBorder()),
                items: _zonas
                    .map((z) => DropdownMenuItem(value: z.nombre, child: Text(z.nombre)))
                    .toList(),
                onChanged: (v) => setState(() => _zona = v),
                validator: (v) => v == null ? 'Selecciona la zona.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _direccion,
                decoration: const InputDecoration(
                    labelText: 'Dirección de referencia', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'La dirección es obligatoria.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descripcion,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Descripción', alignLabelWithHint: true, border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'La descripción es obligatoria.' : null,
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Adjuntar mi ubicación actual'),
                subtitle: Text(_pos == null
                    ? 'Opcional'
                    : '${_pos!.latitude.toStringAsFixed(5)}, ${_pos!.longitude.toStringAsFixed(5)}'),
                value: _usarUbicacion,
                onChanged: _alternarUbicacion,
              ),
              if (_foto != null)
                Stack(alignment: Alignment.topRight, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_foto!, height: 180, width: double.infinity, fit: BoxFit.cover),
                  ),
                  IconButton.filled(
                    onPressed: () => setState(() => _foto = null),
                    icon: const Icon(Icons.close),
                  ),
                ]),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _elegirFoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _elegirFoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _enviando ? null : _enviar,
                  child: _enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enviar reporte'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
