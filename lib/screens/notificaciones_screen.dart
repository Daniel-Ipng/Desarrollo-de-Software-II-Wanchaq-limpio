import 'package:flutter/material.dart';

import '../models/modulos_ciudadanos.dart';
import '../repositories/reporte_repository.dart';

class NotificacionesScreen extends StatefulWidget {
  final ReporteRepository repositorio;

  const NotificacionesScreen({super.key, required this.repositorio});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<Notificacion> _items = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final items = await widget.repositorio.listarNotificaciones();
      if (!mounted) return;
      setState(() {
        _items = items;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = 'No se pudieron cargar las notificaciones.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: _items.any((item) => !item.leida)
                ? () async {
                    await widget.repositorio.marcarTodasNotificacionesLeidas();
                    _cargar();
                  }
                : null,
            child: const Text('Marcar todas'),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _estado(_error!)
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _items.isEmpty
                  ? _estado('No tienes notificaciones.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (_, index) => _tarjeta(_items[index]),
                    ),
            ),
    );
  }

  Widget _tarjeta(Notificacion item) {
    return Card(
      color: item.leida
          ? null
          : Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
      child: ListTile(
        leading: Icon(
          item.leida
              ? Icons.notifications_none_outlined
              : Icons.notifications_active_outlined,
        ),
        title: Text(item.titulo),
        subtitle: Text('${item.mensaje}\n${_fecha(item.creadoEn)}'),
        isThreeLine: true,
        onTap: item.leida
            ? null
            : () async {
                await widget.repositorio.marcarNotificacionLeida(item.id);
                _cargar();
              },
      ),
    );
  }

  Widget _estado(String texto) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(texto, textAlign: TextAlign.center),
    ),
  );

  String _fecha(DateTime fecha) => fecha.toLocal().toString().split('.').first;
}
