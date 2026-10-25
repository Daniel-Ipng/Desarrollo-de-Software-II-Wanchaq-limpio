import 'package:flutter/material.dart';

import 'horarios_screen.dart';
import 'incidencias_screen.dart';
import 'mapa_screen.dart';
import 'perfil_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _i = 0;

  static const _titulos = ['Horarios de recolección', 'Camión en vivo', 'Incidencias', 'Mi perfil'];
  static const _paginas = <Widget>[
    HorariosScreen(),
    MapaScreen(),
    IncidenciasScreen(),
    PerfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titulos[_i])),
      body: _paginas[_i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Horarios'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'Camión'),
          NavigationDestination(icon: Icon(Icons.report_problem_outlined), label: 'Incidencias'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
