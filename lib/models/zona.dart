class Zona {
  final int id;
  final String nombre;
  final String? descripcion;

  const Zona({required this.id, required this.nombre, this.descripcion});

  factory Zona.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! num || json['nombre'] is! String) {
      throw const FormatException('La respuesta de zona no es válida');
    }

    return Zona(
      id: id.toInt(),
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
    );
  }
}
