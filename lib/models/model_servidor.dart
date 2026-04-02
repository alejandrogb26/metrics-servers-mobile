class Servidor {
  final int id;
  final String serverId;
  final String dns;
  final String hostname;
  final String? prettyOs;
  final String? arch;
  final String? kernel;
  final String? imagen;
  final String? imagenUrl;
  final int seccion;
  final List<int> servicios;

  const Servidor({
    required this.id,
    required this.serverId,
    required this.dns,
    required this.hostname,
    this.prettyOs,
    this.arch,
    this.kernel,
    this.imagen,
    this.imagenUrl,
    required this.seccion,
    required this.servicios,
  });

  factory Servidor.fromJson(Map<String, dynamic> json) {
    return Servidor(
      id: json['id'] as int? ?? 0,
      serverId: json['serverId'] as String? ?? '',
      dns: json['dns'] as String? ?? '',
      hostname: json['hostname'] as String? ?? '',
      prettyOs: json['prettyOs'] as String?,
      arch: json['arch'] as String?,
      kernel: json['kernel'] as String?,
      imagen: json['imagen'] as String?,
      imagenUrl: json['imagenUrl'] as String?,
      seccion: json['seccion'] as int? ?? 0,
      servicios: (json['servicios'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}
