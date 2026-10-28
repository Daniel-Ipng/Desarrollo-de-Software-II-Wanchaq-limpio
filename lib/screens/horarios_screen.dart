import 'package:flutter/material.dart';

import '../models/modulos_ciudadanos.dart';
import '../repositories/reporte_repository.dart';

class HorariosScreen extends StatefulWidget {
  final ReporteRepository repositorio;
  final int? zonaId;
  final String? zonaNombre;

  const HorariosScreen({
    super.key,
    required this.repositorio,
    this.zonaId,
    this.zonaNombre,
  });

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  List<HorarioRecoleccion> _horarios = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (widget.zonaId == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final horarios = await widget.repositorio.listarHorarios(widget.zonaId!);
      if (mounted) {
        setState(() {
          _horarios = horarios;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = 'No se pudieron cargar los horarios.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Horarios de recolección')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    widget.zonaId == null
                        ? 'No tienes una zona de residencia asignada.'
                        : 'Zona: ${widget.zonaNombre ?? 'Sin nombre'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_horarios.isNotEmpty) _proximaRecoleccion(),
                  if (widget.zonaId != null && _horarios.isEmpty)
                    const Text('No hay horarios publicados para esta zona.')
                  else
                    ..._horarios.map(_tarjeta),
                ],
              ),
            ),
    );
  }

  Widget _proximaRecoleccion() {
    final ahora = DateTime.now();
    HorarioRecoleccion? proximo;
    int? diasRestantes;
    for (var offset = 0; offset < 7; offset++) {
      final dia = (ahora.weekday % 7 + offset) % 7;
      final candidatos = _horarios.where((item) => item.diaSemana == dia);
      if (candidatos.isNotEmpty) {
        proximo = candidatos.first;
        diasRestantes = offset;
        break;
      }
    }
    if (proximo == null || diasRestantes == null) {
      return const SizedBox.shrink();
    }
    final textoDia = diasRestantes == 0
        ? 'hoy'
        : diasRestantes == 1
        ? 'mañana'
        : 'en $diasRestantes días';
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.event_available_outlined),
        title: Text('Próxima recolección: $textoDia'),
        subtitle: Text(
          '${proximo.horaInicio} - ${proximo.horaFin} · ${proximo.tipoResiduo}',
        ),
      ),
    );
  }

  Widget _tarjeta(HorarioRecoleccion horario) {
    const dias = [
      'Domingo',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
    ];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.schedule_outlined),
        title: Text(dias[horario.diaSemana]),
        subtitle: Text(
          '${horario.horaInicio} - ${horario.horaFin}\nResiduo: ${horario.tipoResiduo}',
        ),
        isThreeLine: true,
      ),
    );
  }
}
