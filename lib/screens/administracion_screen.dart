import 'package:flutter/material.dart';

import '../repositories/administracion_repository.dart';

class AdministracionScreen extends StatefulWidget {
  final AdministracionRepository repositorio;

  const AdministracionScreen({super.key, required this.repositorio});

  @override
  State<AdministracionScreen> createState() => _AdministracionScreenState();
}

class _AdministracionScreenState extends State<AdministracionScreen> {
  int _tab = 0;
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _datos = [];
  final _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = switch (_tab) {
        0 => await widget.repositorio.listarUsuarios(),
        1 => await widget.repositorio.listarCamiones(),
        2 => await widget.repositorio.listarZonas(),
        3 => await widget.repositorio.listarRutas(),
        4 => await widget.repositorio.listarTiposResiduo(),
        5 => await widget.repositorio.listarRecolecciones(),
        _ => await widget.repositorio.listarAuditoria(),
      };
      if (mounted) setState(() => _datos = datos);
    } catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _mensajeError(Object error) {
    final texto = error.toString();
    return texto.contains('duplicate') || texto.contains('23505')
        ? 'Ya existe un registro con ese identificador.'
        : 'No se pudo cargar el módulo. Comprueba los permisos y la conexión.';
  }

  @override
  Widget build(BuildContext context) {
    final titulos = [
      'Usuarios',
      'Camiones',
      'Zonas',
      'Rutas',
      'Residuos',
      'Recolecciones',
      'Auditoría',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titulos[_tab], style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: List.generate(
                titulos.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(titulos[index]),
                    selected: _tab == index,
                    onSelected: (_) {
                      setState(() {
                        _tab = index;
                        _datos = [];
                      });
                      _cargar();
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_tab == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _busqueda,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre, DNI o correo',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          Expanded(child: _cuerpo()),
        ],
      ),
      floatingActionButton: _tab == 1 || _tab == 2 || _tab == 3 || _tab == 4
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            )
          : null,
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    var datos = _datos;
    if (_tab == 0 && _busqueda.text.trim().isNotEmpty) {
      final termino = _busqueda.text.trim().toLowerCase();
      datos = datos.where((dato) {
        final texto =
            '${dato['nombres']} ${dato['apellidos']} ${dato['dni']} ${dato['correo']}'
                .toLowerCase();
        return texto.contains(termino);
      }).toList();
    }
    if (datos.isEmpty) return const Center(child: Text('No hay registros para mostrar.'));
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: datos.length,
        itemBuilder: (_, index) => _tarjeta(datos[index]),
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> dato) {
    final titulo = switch (_tab) {
      0 => '${dato['nombres'] ?? ''} ${dato['apellidos'] ?? ''}'.trim(),
      1 => '${dato['placa'] ?? ''} · ${dato['modelo'] ?? 'Sin modelo'}',
      2 => '${dato['nombre'] ?? ''}',
      3 => '${dato['nombre'] ?? ''}',
      4 => '${dato['nombre'] ?? ''}',
      5 => 'Recolección #${dato['id'] ?? ''}',
      _ => '${dato['entidad'] ?? ''} · ${dato['operacion'] ?? ''}',
    };
    final subtitulo = switch (_tab) {
      0 => '${dato['correo'] ?? ''}\nRol: ${dato['rol'] ?? 'ciudadano'} · ${dato['activo'] == true ? 'Activo' : 'Inactivo'}',
      1 => 'Estado: ${dato['estado'] ?? ''} · Zona: ${(dato['zonas'] as Map?)?['nombre'] ?? 'Sin asignar'}',
      2 => '${dato['descripcion'] ?? 'Sin descripción'} · Contenedores: ${dato['contenedores'] ?? 0}',
      3 => 'Zona: ${(dato['zonas'] as Map?)?['nombre'] ?? 'Sin asignar'} · Turno: ${dato['turno'] ?? ''}',
      4 => '${dato['descripcion'] ?? 'Sin descripción'} · Contenedor: ${dato['contenedor_recomendado'] ?? 'Sin definir'}',
      5 => '${dato['tipo_residuo'] ?? ''} · ${dato['cantidad_kg'] ?? 0} kg · ${dato['estado'] ?? ''}',
      _ => '${dato['creado_en'] ?? ''} · Registro: ${dato['registro_id'] ?? 'N/D'}',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_icono())),
        title: Text(titulo.isEmpty ? 'Sin nombre' : titulo),
        subtitle: Text(subtitulo),
        isThreeLine: true,
        trailing: _tab == 0
            ? Switch(
                value: dato['activo'] == true,
                onChanged: (value) => _cambiarEstadoUsuario(dato, value),
              )
            : _tab == 1 || _tab == 2 || _tab == 3 || _tab == 4
            ? IconButton(
                tooltip: 'Editar',
                onPressed: () => _abrirFormulario(dato),
                icon: const Icon(Icons.edit_outlined),
              )
            : null,
      ),
    );
  }

  IconData _icono() => switch (_tab) {
    0 => Icons.person_outline,
    1 => Icons.local_shipping_outlined,
    2 => Icons.location_on_outlined,
    3 => Icons.route_outlined,
    5 => Icons.recycling_outlined,
    _ => Icons.history_outlined,
  };

  Future<void> _cambiarEstadoUsuario(Map<String, dynamic> dato, bool activo) async {
    try {
      await widget.repositorio.actualizarEstadoUsuario(dato['id'] as String, activo);
      await _cargar();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_mensajeError(error))));
    }
  }

  Future<void> _abrirFormulario([Map<String, dynamic>? dato]) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioAdministrativo(
        tipo: _tab,
        dato: dato,
        repositorio: widget.repositorio,
      ),
    );
    if (resultado == true) _cargar();
  }
}

class _FormularioAdministrativo extends StatefulWidget {
  final int tipo;
  final Map<String, dynamic>? dato;
  final AdministracionRepository repositorio;

  const _FormularioAdministrativo({
    required this.tipo,
    required this.dato,
    required this.repositorio,
  });

  @override
  State<_FormularioAdministrativo> createState() => _FormularioAdministrativoState();
}

class _FormularioAdministrativoState extends State<_FormularioAdministrativo> {
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _extra;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final dato = widget.dato;
    _nombre = TextEditingController(text: dato?['placa'] ?? dato?['nombre'] ?? '');
    _descripcion = TextEditingController(text: dato?['modelo'] ?? dato?['descripcion'] ?? '');
    _extra = TextEditingController(
      text: '${dato?['capacidad_kg'] ?? dato?['contenedores'] ?? dato?['contenedor_recomendado'] ?? ''}',
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _extra.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esCamion = widget.tipo == 1;
    final esZona = widget.tipo == 2;
    return AlertDialog(
      title: Text(widget.dato == null ? 'Agregar registro' : 'Editar registro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nombre, decoration: InputDecoration(labelText: esCamion ? 'Placa' : 'Nombre')),
            TextField(controller: _descripcion, decoration: InputDecoration(labelText: esCamion ? 'Modelo' : 'Descripción')),
            TextField(
              controller: _extra,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: esCamion ? 'Capacidad (kg)' : esZona ? 'Contenedores' : 'Contenedor recomendado'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar')),
      ],
    );
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    try {
      final id = (widget.dato?['id'] as num?)?.toInt();
      if (widget.tipo == 1) {
        await widget.repositorio.guardarCamion(
          id: id,
          placa: _nombre.text,
          modelo: _descripcion.text,
          capacidadKg: double.tryParse(_extra.text),
        );
      } else if (widget.tipo == 2) {
        await widget.repositorio.guardarZona(
          id: id,
          nombre: _nombre.text,
          descripcion: _descripcion.text,
          contenedores: int.tryParse(_extra.text) ?? 0,
        );
      } else if (widget.tipo == 3) {
        await widget.repositorio.guardarRuta(
          id: id,
          nombre: _nombre.text,
          zonaId: int.tryParse(_extra.text) ?? 0,
          turno: _descripcion.text.trim().isEmpty ? 'manana' : _descripcion.text.trim(),
        );
      } else {
        await widget.repositorio.guardarTipoResiduo(
          id: id,
          nombre: _nombre.text,
          descripcion: _descripcion.text,
          contenedor: _extra.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: ${error.toString()}')),
        );
        setState(() => _guardando = false);
      }
    }
  }
}
