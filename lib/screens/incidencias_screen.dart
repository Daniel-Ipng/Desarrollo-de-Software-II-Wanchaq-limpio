import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../models.dart';
import '../utils.dart';
import 'nueva_incidencia_screen.dart';

class IncidenciasScreen extends StatefulWidget {
  const IncidenciasScreen({super.key});
  @override
  State<IncidenciasScreen> createState() => _IncidenciasScreenState();
}

class _IncidenciasScreenState extends State<IncidenciasScreen> {
  late Future<List<Incidencia>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = Api.misIncidencias();
  }

  void _recargar() => setState(() => _futuro = Api.misIncidencias());

  Future<void> _nueva() async {
    final creada = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const NuevaIncidenciaScreen()));
    if (creada == true) _recargar();
  }

  (String, Color) _estado(String e) => switch (e) {
        'en_atencion' => ('En atención', Colors.blue),
        'resuelta' => ('Resuelta', Colors.green),
        _ => ('Pendiente', Colors.orange),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nueva,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Reportar'),
      ),
      body: FutureBuilder<List<Incidencia>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorVista(mensajeError: '${snap.error}', onReintentar: _recargar);
          }
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aún no has reportado incidencias.\nToca "Reportar" para crear la primera.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: lista.length,
              itemBuilder: (_, i) {
                final inc = lista[i];
                final (texto, color) = _estado(inc.estado);
                return Card(
                  child: ListTile(
                    leading: (inc.fotoUrl != null && inc.fotoUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(Config.archivo(inc.fotoUrl),
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported)),
                          )
                        : const Icon(Icons.report_problem_outlined),
                    title: Text(inc.tipo),
                    subtitle: Text('${inc.direccion}\n${fmtFecha(inc.fecha)}'),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(texto, style: TextStyle(color: color, fontSize: 12)),
                      side: BorderSide(color: color),
                      backgroundColor: color.withOpacity(0.08),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
