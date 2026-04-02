class Servicio {
  final int id;
  final String nombre;
  final String? logo;

  const Servicio({
    required this.id,
    required this.nombre,
    this.logo,
  });

  factory Servicio.fromJson(Map<String, dynamic> json) {
    return Servicio(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      logo: json['urlLogo'] as String?,
    );
  }
}
