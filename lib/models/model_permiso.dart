class Ambito {
  final int id;
  final String nombre;
  final String? descripcion;

  const Ambito({
    required this.id,
    required this.nombre,
    this.descripcion,
  });

  factory Ambito.fromJson(Map<String, dynamic> json) {
    return Ambito(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
    );
  }
}

class Permiso {
  final int id;
  final String nombre;
  final String? descripcion;
  final Ambito ambito;

  const Permiso({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.ambito,
  });

  factory Permiso.fromJson(Map<String, dynamic> json) {
    return Permiso(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      ambito: Ambito.fromJson(json['ambito'] as Map<String, dynamic>),
    );
  }
}
