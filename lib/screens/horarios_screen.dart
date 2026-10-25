import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../utils.dart';

class HorariosScreen extends StatefulWidget {
  const HorariosScreen({super.key});
  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  late Future<List<dynamic>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<List<dynamic>> _cargar() => Future.wait<dynamic>([Api.zonas(), Api.tiposResiduo()]);

  void _recargar() => setState(() => _futuro = _cargar());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorVista(mensajeError: '${snap.error}', onReintentar: _recargar);
        }
        final zonas = (snap.data![0] as List<Zona>).where((z) => z.estado == 'activa').toList();
        final tipos = snap.data![1] as List<TipoResiduo>;
        final miNombreZona = Api.sesion.value?.zona;
        Zona? miZona;
        for (final z in zonas) {
          if (z.nombre == miNombreZona) miZona = z;
        }

        return RefreshIndicator(
          onRefresh: () async => _recargar(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _tarjetaMiZona(context, miZona),
              const SizedBox(height: 20),
              Text('Cómo separar tus residuos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...tipos.map(_tarjetaTipo),
              const SizedBox(height: 20),
              Text('Todas las zonas', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...zonas.map((z) => Card(
                    child: ListTile(
                      title: Text(z.nombre),
                      subtitle: Text('${z.horarioRecoleccion ?? '-'}\n${z.referencia ?? ''}'),
                      isThreeLine: true,
                      trailing: Text(z.tipoResiduoPrincipal ?? ''),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _tarjetaMiZona(BuildContext context, Zona? z) {
    final esquema = Theme.of(context).colorScheme;
    if (z == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.map_outlined),
          title: Text('No tienes una zona configurada'),
        ),
      );
    }
    return Card(
      color: esquema.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.location_on),
            const SizedBox(width: 8),
            Text('Tu zona: ${z.nombre}', style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 8),
          Text('Horario: ${z.horarioRecoleccion ?? '-'}'),
          Text('Referencia: ${z.referencia ?? '-'}'),
          const SizedBox(height: 8),
          Chip(label: Text('Residuo principal: ${z.tipoResiduoPrincipal ?? '-'}')),
        ]),
      ),
    );
  }

  Widget _tarjetaTipo(TipoResiduo t) {
    final c = colorDesdeHex(t.color);
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.withOpacity(0.2), child: Icon(Icons.delete_outline, color: c)),
        title: Text(t.nombre),
        subtitle: Text([
          if (t.descripcion != null) t.descripcion!,
          if (t.diasRecomendados.isNotEmpty) 'Días: ${t.diasRecomendados.join(', ')}',
          if (t.contenedor != null) 'Contenedor: ${t.contenedor}',
        ].join('\n')),
        isThreeLine: true,
      ),
    );
  }
}
