class Seccion {
  final int id;
  final String nombre;
  final String? descripcion;

  const Seccion({
    required this.id,
    required this.nombre,
    this.descripcion,
  });

  factory Seccion.fromJson(Map<String, dynamic> json) {
    return Seccion(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
    );
  }
}
