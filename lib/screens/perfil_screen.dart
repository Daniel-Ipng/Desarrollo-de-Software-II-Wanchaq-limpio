import 'package:flutter/material.dart';

import '../api.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = Api.sesion.value;
    if (u == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 44)),
        const SizedBox(height: 12),
        Center(child: Text(u.nombreCompleto, style: Theme.of(context).textTheme.titleLarge)),
        Center(child: Text(u.correo)),
        const SizedBox(height: 20),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.map_outlined), title: const Text('Zona'), subtitle: Text(u.zona ?? '-')),
            ListTile(leading: const Icon(Icons.home_outlined), title: const Text('Dirección'), subtitle: Text(u.direccion ?? '-')),
            ListTile(leading: const Icon(Icons.phone_android), title: const Text('Celular'), subtitle: Text(u.telefono ?? '-')),
            ListTile(
              leading: const Icon(Icons.eco_outlined),
              title: Text(u.nivelEcologico ?? 'Eco Semilla'),
              subtitle: Text('${u.kgReciclados.toStringAsFixed(1)} kg reciclados'),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: Api.cerrarSesion,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}
