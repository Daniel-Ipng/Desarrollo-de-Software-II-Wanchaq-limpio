import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.cargarSesion();
  runApp(const EcoCuscoApp());
}

class EcoCuscoApp extends StatelessWidget {
  const EcoCuscoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRutas Wanchaq',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      // Si la sesión se cierra (o expira), vuelve sola al login.
      home: ValueListenableBuilder<Usuario?>(
        valueListenable: Api.sesion,
        builder: (_, usuario, __) =>
            usuario == null ? const LoginScreen() : const HomeScreen(),
      ),
    );
  }
}
