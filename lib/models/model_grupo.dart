class GrupoPermissionMap {
  final List<int> global;
  final Map<String, List<int>> sections;

  const GrupoPermissionMap({
    required this.global,
    required this.sections,
  });

  factory GrupoPermissionMap.fromJson(Map<String, dynamic> json) {
    final global =
        (json['global'] as List<dynamic>?)?.map((e) => e as int).toList() ??
            [];
    final sections = <String, List<int>>{};
    if (json['sections'] != null) {
      (json['sections'] as Map<String, dynamic>).forEach((key, value) {
        sections[key] = (value as List<dynamic>).map((e) => e as int).toList();
      });
    }
    return GrupoPermissionMap(global: global, sections: sections);
  }
}

class Grupo {
  final int id;
  final String nombre;
  final String dn;
  final bool superAdmin;
  final GrupoPermissionMap? permisos;

  const Grupo({
    required this.id,
    required this.nombre,
    required this.dn,
    required this.superAdmin,
    this.permisos,
  });

  factory Grupo.fromJson(Map<String, dynamic> json) {
    return Grupo(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      dn: json['dn'] as String? ?? '',
      superAdmin: json['superAdmin'] as bool? ?? false,
      permisos: json['permisos'] != null
          ? GrupoPermissionMap.fromJson(
              json['permisos'] as Map<String, dynamic>)
          : null,
    );
  }

  List<int> allPermissionIds() {
    if (permisos == null) return [];
    final all = <int>{...permisos!.global};
    for (final list in permisos!.sections.values) {
      all.addAll(list);
    }
    return all.toList();
  }
}
