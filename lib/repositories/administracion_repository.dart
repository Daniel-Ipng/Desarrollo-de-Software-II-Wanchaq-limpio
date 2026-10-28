import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class ResumenAdministrativo {
  final int usuarios;
  final int ciudadanos;
  final int operadores;
  final int administradores;
  final int usuariosInactivos;
  final int camiones;
  final int camionesOperativos;
  final int camionesMantenimiento;
  final int zonas;
  final int rutas;
  final int recolecciones;
  final int incidenciasPendientes;
  final int incidenciasEnProceso;
  final int incidenciasResueltas;

  const ResumenAdministrativo({
    required this.usuarios,
    required this.ciudadanos,
    required this.operadores,
    required this.administradores,
    required this.usuariosInactivos,
    required this.camiones,
    required this.camionesOperativos,
    required this.camionesMantenimiento,
    required this.zonas,
    required this.rutas,
    required this.recolecciones,
    required this.incidenciasPendientes,
    required this.incidenciasEnProceso,
    required this.incidenciasResueltas,
  });
}

class AdministracionRepository {
  SupabaseClient get _db => SupabaseService.client;

  Future<void> verificarAcceso() async {
    final result = await _db.rpc('es_administrador');
    if (result != true) {
      throw const AuthException('No tienes permisos para esta operación.');
    }
  }

  Future<ResumenAdministrativo> cargarResumen() async {
    await verificarAcceso();
    final resultados = await Future.wait([
      _db.from('perfiles').select('rol, activo'),
      _db.from('camiones').select('id, estado, activo'),
      _db.from('zonas').select('id, activo'),
      _db.from('rutas').select('id, activo'),
      _db.from('recolecciones').select('id'),
      _db.from('reportes').select('estado'),
    ]);
    final perfiles = _maps(resultados[0]);
    final camiones = _maps(resultados[1]);
    final zonas = _maps(resultados[2]);
    final rutas = _maps(resultados[3]);
    final reportes = _maps(resultados[5]);
    int rol(String valor) =>
        perfiles.where((p) => p['rol'] == valor && p['activo'] == true).length;
    int estadoReporte(String valor) =>
        reportes.where((r) => r['estado'] == valor).length;

    return ResumenAdministrativo(
      usuarios: perfiles.length,
      ciudadanos: rol('ciudadano'),
      operadores: rol('operador'),
      administradores:
          rol('admin') + rol('administrador'),
      usuariosInactivos: perfiles.where((p) => p['activo'] != true).length,
      camiones: camiones.where((c) => c['activo'] == true).length,
      camionesOperativos: camiones
          .where((c) => c['activo'] == true && c['estado'] == 'operativo')
          .length,
      camionesMantenimiento: camiones
          .where((c) => c['activo'] == true && c['estado'] == 'mantenimiento')
          .length,
      zonas: zonas.where((z) => z['activo'] == true).length,
      rutas: rutas.where((r) => r['activo'] == true).length,
      recolecciones: _maps(resultados[4]).length,
      incidenciasPendientes: estadoReporte('pendiente'),
      incidenciasEnProceso: estadoReporte('enProceso'),
      incidenciasResueltas: estadoReporte('resuelto'),
    );
  }

  Future<List<Map<String, dynamic>>> listarUsuarios({
    String? busqueda,
    String? rol,
    bool? activo,
  }) async {
    await verificarAcceso();
    final datos = await _db
        .from('perfiles')
        .select(
          'id, nombres, apellidos, dni, correo, telefono, rol, zona_id, activo',
        )
        .order('nombres');
    var usuarios = _maps(datos);
    if (rol != null) usuarios = usuarios.where((u) => u['rol'] == rol).toList();
    if (activo != null) {
      usuarios = usuarios.where((u) => u['activo'] == activo).toList();
    }
    final termino = busqueda?.trim().toLowerCase();
    if (termino != null && termino.isNotEmpty) {
      usuarios = usuarios.where((u) {
        final texto =
            '${u['nombres'] ?? ''} ${u['apellidos'] ?? ''} ${u['dni'] ?? ''} ${u['correo'] ?? ''}'
                .toLowerCase();
        return texto.contains(termino);
      }).toList();
    }
    return usuarios;
  }

  Future<void> actualizarEstadoUsuario(String id, bool activo) async {
    await verificarAcceso();
    await _db.from('perfiles').update({'activo': activo}).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listarCamiones() async {
    await verificarAcceso();
    return _maps(await _db.from('camiones').select().order('placa'));
  }

  Future<void> guardarCamion({
    int? id,
    required String placa,
    String? modelo,
    double? capacidadKg,
    int? zonaId,
    String estado = 'operativo',
  }) async {
    await verificarAcceso();
    final datos = {
      'placa': placa.trim().toUpperCase(),
      'modelo': modelo?.trim().isEmpty == true ? null : modelo?.trim(),
      'capacidad_kg': capacidadKg,
      'zona_id': zonaId,
      'estado': estado,
      'activo': true,
    };
    if (id == null) {
      await _db.from('camiones').insert(datos);
    } else {
      await _db.from('camiones').update(datos).eq('id', id);
    }
  }

  Future<List<Map<String, dynamic>>> listarZonas() async {
    await verificarAcceso();
    return _maps(await _db.from('zonas').select().order('nombre'));
  }

  Future<void> guardarZona({
    int? id,
    required String nombre,
    String? descripcion,
    required int contenedores,
  }) async {
    await verificarAcceso();
    final datos = {
      'nombre': nombre.trim(),
      'descripcion': descripcion?.trim(),
      'contenedores': contenedores,
      'activo': true,
    };
    if (id == null) {
      await _db.from('zonas').insert(datos);
    } else {
      await _db.from('zonas').update(datos).eq('id', id);
    }
  }

  Future<List<Map<String, dynamic>>> listarRutas() async {
    await verificarAcceso();
    return _maps(await _db
        .from('rutas')
        .select()
        .order('nombre'));
  }

  Future<void> guardarRuta({
    int? id,
    required String nombre,
    required int zonaId,
    String turno = 'manana',
  }) async {
    await verificarAcceso();
    final datos = {
      'nombre': nombre.trim(),
      'zona_id': zonaId,
      'turno': turno,
      'activo': true,
    };
    if (id == null) {
      await _db.from('rutas').insert(datos);
    } else {
      await _db.from('rutas').update(datos).eq('id', id);
    }
  }

  Future<List<Map<String, dynamic>>> listarRecolecciones() async {
    await verificarAcceso();
    return _maps(await _db.from('recolecciones').select(
      'id, zona_id, camion_id, tipo_residuo, cantidad_kg, recolectado_en, estado, observaciones',
    ).order('recolectado_en', ascending: false));
  }

  Future<List<Map<String, dynamic>>> listarAuditoria() async {
    await verificarAcceso();
    return _maps(await _db.from('auditoria').select().order('creado_en', ascending: false));
  }

  Future<List<Map<String, dynamic>>> listarTiposResiduo() async {
    await verificarAcceso();
    return _maps(await _db.from('tipos_residuo').select().order('nombre'));
  }

  Future<void> guardarTipoResiduo({
    int? id,
    required String nombre,
    String? descripcion,
    String? contenedor,
  }) async {
    await verificarAcceso();
    final datos = {
      'nombre': nombre.trim(),
      'descripcion': descripcion?.trim(),
      'contenedor_recomendado': contenedor?.trim(),
      'activo': true,
    };
    if (id == null) {
      await _db.from('tipos_residuo').insert(datos);
    } else {
      await _db.from('tipos_residuo').update(datos).eq('id', id);
    }
  }

  List<Map<String, dynamic>> _maps(Object value) =>
      (value as List).whereType<Map<String, dynamic>>().toList();
}
