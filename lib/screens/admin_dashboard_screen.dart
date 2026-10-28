import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../repositories/usuario_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Usuario usuario;
  final UsuarioRepository repositorio;
  final VoidCallback alCerrarSesion;

  const AdminDashboardScreen({
    super.key,
    required this.usuario,
    required this.repositorio,
    required this.alCerrarSesion,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _verificando = true;
  String? _error;

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
      if (mounted) setState(() => _verificando = false);
    } on AuthException catch (_) {
      widget.alCerrarSesion();
      return;
    } catch (_) {
      _mostrarError();
    }
  }

  void _mostrarError() {
    if (!mounted) return;
    setState(() {
      _verificando = false;
      _error = 'No se pudo validar el acceso. Comprueba tu conexión e inténtalo de nuevo.';
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
            ? Center(
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
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
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
                          'Bienvenido al espacio de gestión',
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
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Módulos',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _modulo(
                    context,
                    icono: Icons.assignment_outlined,
                    titulo: 'Incidencias',
                    descripcion: 'Espacio inicial para la gestión de reportes.',
                  ),
                  _modulo(
                    context,
                    icono: Icons.people_outline,
                    titulo: 'Ciudadanos',
                    descripcion: 'Herramientas de gestión disponibles próximamente.',
                  ),
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
                              'El acceso a este panel se verifica en el servidor para cada sesión.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
      ),
    );
  }
}
