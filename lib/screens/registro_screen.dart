import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../utils.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _form = GlobalKey<FormState>();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _dni = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _pass = TextEditingController();

  List<Zona> _zonas = [];
  String? _zona;
  String? _errorZonas;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarZonas();
  }

  @override
  void dispose() {
    for (final c in [_nombres, _apellidos, _dni, _correo, _telefono, _direccion, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarZonas() async {
    setState(() => _errorZonas = null);
    try {
      final z = await Api.zonas();
      if (!mounted) return;
      setState(() => _zonas = z.where((e) => e.estado == 'activa').toList());
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorZonas = e.message);
    }
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await Api.registrarCiudadano(
        correo: _correo.text,
        dni: _dni.text,
        nombres: _nombres.text,
        apellidos: _apellidos.text,
        telefono: _telefono.text,
        password: _pass.text,
        zona: _zona!,
        direccion: _direccion.text,
      );
      // La sesión ya quedó iniciada: cerramos esta pantalla para ver el Home.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) mensaje(context, e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  InputDecoration _dec(String label, IconData icono) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icono),
        border: const OutlineInputBorder(),
      );

  String? _req(String? v, String msg) => (v == null || v.trim().isEmpty) ? msg : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(children: [
              TextFormField(
                controller: _nombres,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Nombres', Icons.badge_outlined),
                validator: (v) => _req(v, 'Los nombres son obligatorios.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apellidos,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Apellidos', Icons.badge_outlined),
                validator: (v) => _req(v, 'Los apellidos son obligatorios.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dni,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: _dec('DNI', Icons.credit_card),
                validator: (v) => RegExp(r'^\d{8}$').hasMatch(v ?? '')
                    ? null
                    : 'El DNI debe tener exactamente 8 dígitos.',
              ),
              TextFormField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Correo electrónico', Icons.email_outlined),
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Ingresa un correo válido.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                decoration: _dec('Celular (9 dígitos)', Icons.phone_android),
                validator: (v) => RegExp(r'^9\d{8}$').hasMatch(v ?? '')
                    ? null
                    : 'Celular peruano válido: 9 dígitos, empieza en 9.',
              ),
              if (_errorZonas != null)
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_errorZonas!),
                  trailing: IconButton(
                      icon: const Icon(Icons.refresh), onPressed: _cargarZonas),
                )
              else
                DropdownButtonFormField<String>(
                  value: _zona,
                  isExpanded: true,
                  decoration: _dec('Zona de residencia', Icons.map_outlined),
                  items: _zonas
                      .map((z) => DropdownMenuItem(value: z.nombre, child: Text(z.nombre)))
                      .toList(),
                  onChanged: (v) => setState(() => _zona = v),
                  validator: (v) => v == null ? 'Selecciona tu zona.' : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _direccion,
                decoration: _dec('Dirección (calle/avenida y número)', Icons.home_outlined),
                validator: (v) => _req(v, 'Ingresa tu dirección.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: _dec('Contraseña', Icons.lock_outline),
                validator: (v) => RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(v ?? '')
                    ? null
                    : 'Mínimo 8 caracteres, con letras y números.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _cargando ? null : _registrar,
                  child: _cargando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Registrarme'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
