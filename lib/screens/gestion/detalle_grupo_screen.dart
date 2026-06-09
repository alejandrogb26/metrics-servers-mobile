/// detalle_grupo_screen.dart
///
/// Propósito:
///   Pantalla de detalle de un grupo de usuarios. Muestra la información completa
///   del grupo: datos de identidad (ID, nombre, DN, superAdmin) y el desglose de
///   permisos asignados, tanto globales como por sección, resolviendo los IDs
///   numéricos de permiso a nombres y ámbitos legibles mediante [GrupoProvider].
///
/// Capa arquitectónica:
///   Capa de presentación — pantallas de gestión (screens/gestion/).
///
/// Clases definidas en este fichero:
///   - [DetalleGrupoScreen]: StatelessWidget raíz de la pantalla de detalle.
///   - [_PermisosTable]:     Tabla privada que resuelve IDs de permiso a objetos
///                           [Permiso] completos y los renderiza.
///
/// Recepción de datos — argumento de navegación:
///   La pantalla recibe el objeto [Grupo] completo a través de
///   `ModalRoute.of(context)!.settings.arguments as Grupo`. Este objeto es el
///   mismo que seleccionó el usuario en [GruposScreen] y ya contiene todos los
///   datos necesarios (incluyendo `permisos` si api-py los devolvió). No se
///   realiza ninguna petición HTTP adicional para mostrar esta pantalla.
///
/// Resolución de IDs de permiso:
///   [GrupoPermissionMap] almacena los permisos como listas de IDs enteros.
///   Para mostrar nombre, descripción y ámbito de cada permiso, [_PermisosTable]
///   usa [GrupoProvider.getPermisoById] que busca en el catálogo cargado por
///   [GruposScreen]. Si el catálogo no está cargado (navegación directa sin
///   pasar por [GruposScreen]), los permisos se mostrarán como `#id` (fallback).
///
/// Estructura de la pantalla:
///   1. AppBar con nombre del grupo y badge SUPERADMIN condicional.
///   2. Card de información general (ID, nombre, DN, superAdmin).
///   3. Card de permisos globales (solo si `permisos.global` no está vacío).
///   4. Card de permisos por sección (solo si `permisos.sections` no está vacío).
///   5. Card "Sin permisos asignados" (solo si `grupo.permisos` es `null`).
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas (la carga se hace en GruposScreen / GrupoProvider).
///   - Lógica de edición o eliminación de grupos (no implementada actualmente).
///   - Navegación hacia otras pantallas.
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_grupo.dart';
import 'package:metrics_servers_mobile/providers/grupo_provider.dart';
import 'package:provider/provider.dart';

/// Pantalla de detalle completo de un grupo de usuarios.
///
/// Responsabilidad:
///   Presenta toda la información de un [Grupo] en secciones organizadas por
///   tipo de dato: identidad y permisos. Es una pantalla de solo lectura; no
///   ofrece acciones de edición en esta versión.
///
/// Diseño — StatelessWidget con `context.read`:
///   La pantalla es un [StatelessWidget] porque no necesita reaccionar a cambios
///   del provider tras el primer build. El [Grupo] viene del argumento de ruta
///   (datos ya cargados) y el proveedor se lee sin suscripción (`context.read`)
///   para pasarlo a [_PermisosTable] como referencia de catálogo estático.
///
/// Relación con otros módulos:
///   - [GruposScreen]: pantalla origen; pasa el [Grupo] como argumento de ruta.
///   - [GrupoProvider]: fuente del catálogo de permisos para resolución de IDs.
///   - [GrupoPermissionMap]: estructura de permisos cuyas listas de IDs se
///     resuelven visualmente en [_PermisosTable].
class DetalleGrupoScreen extends StatelessWidget {
  const DetalleGrupoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // El objeto Grupo se recibe como argumento de navegación desde GruposScreen.
    // El cast directo lanzará TypeError si se navega sin argumento o con un tipo
    // incorrecto; se asume que la navegación siempre proviene de GruposScreen.
    final grupo = ModalRoute.of(context)!.settings.arguments as Grupo;

    // Se lee el provider sin escucha: solo se necesita para resolver IDs de
    // permiso en _PermisosTable, que es una operación síncrona sobre el catálogo
    // en memoria. No hay necesidad de reconstruir la pantalla si el provider cambia.
    final grupoProvider = context.read<GrupoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(grupo.nombre),
        actions: [
          // Badge SUPERADMIN en la AppBar: visible de inmediato sin ocupar
          // espacio en el cuerpo de la pantalla.
          if (grupo.superAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: StatusBadge(
                  label: 'SUPERADMIN',
                  color: const Color(0xFFE3B341),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card de información general ────────────────────────────────
            // Muestra los campos de identidad del grupo siempre,
            // independientemente de si tiene permisos asignados.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Información del grupo',
                      icon: Icons.group_outlined,
                    ),
                    InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'ID',
                      value: grupo.id.toString(),
                    ),
                    InfoRow(
                      icon: Icons.label_outline,
                      label: 'Nombre',
                      value: grupo.nombre,
                    ),
                    InfoRow(
                      icon: Icons.account_tree_outlined,
                      label: 'DN (Distinguished Name)',
                      value: grupo.dn,
                    ),
                    InfoRow(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Superadmin',
                      value: grupo.superAdmin ? 'Sí' : 'No',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Sección de permisos ────────────────────────────────────────
            // Solo se renderiza si el objeto Grupo incluye datos de permisos.
            // Si grupo.permisos es null, api-py no devolvió el detalle de
            // permisos para este grupo (p. ej. listado sin detalle).
            if (grupo.permisos != null) ...[
              // Card de permisos globales: solo si la lista no está vacía.
              if (grupo.permisos!.global.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Permisos globales',
                          icon: Icons.public,
                        ),
                        _PermisosTable(
                          permisoIds: grupo.permisos!.global,
                          grupoProvider: grupoProvider,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Card de permisos por sección: solo si el mapa no está vacío.
              // Cada entrada del mapa genera un sub-bloque con el nombre de
              // sección y su tabla de permisos correspondiente.
              if (grupo.permisos!.sections.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Permisos por sección',
                          icon: Icons.folder_outlined,
                        ),
                        // Itera sobre cada sección del mapa de permisos.
                        // entry.key es el ID de sección (string); entry.value
                        // es la lista de IDs de permiso para esa sección.
                        // Nota: la clave de sección se muestra como "Sección {key}"
                        // sin resolver al nombre completo del objeto Seccion.
                        ...grupo.permisos!.sections.entries.map(
                          (entry) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.folder,
                                      size: 14,
                                      color: Color(0xFF8B949E),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Sección ${entry.key}',
                                      style: const TextStyle(
                                        color: Color(0xFF8B949E),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _PermisosTable(
                                permisoIds: entry.value,
                                grupoProvider: grupoProvider,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ] else
              // grupo.permisos == null: api-py no devolvió datos de permisos.
              // Distinto de "permisos vacíos": aquí directamente no hay datos.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_open_outlined,
                        color: Color(0xFF8B949E),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Sin permisos asignados',
                        style: TextStyle(color: Color(0xFF8B949E)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Tabla de permisos ──────────────────────────────────────────────────────────

/// Tabla de permisos que resuelve una lista de IDs a objetos [Permiso] completos.
///
/// Responsabilidad:
///   Renderiza una [Table] de tres columnas (Nombre, Descripción, Ámbito) para
///   una lista de IDs de permiso. Para cada ID usa [GrupoProvider.getPermisoById]
///   para obtener el objeto [Permiso] correspondiente del catálogo en memoria.
///
/// Fallback ante permiso no encontrado:
///   Si [GrupoProvider.getPermisoById] devuelve `null` (el ID no existe en el
///   catálogo cargado, p. ej. por navegación directa sin pasar por [GruposScreen]):
///   - Nombre: se muestra `#id` como referencia técnica al ID numérico.
///   - Descripción: se muestra `-`.
///   - Ámbito: se muestra un widget vacío ([SizedBox.shrink]).
///
/// Proporciones de columnas (ratio FlexColumnWidth):
///   - Nombre (2):      nombre corto del permiso.
///   - Descripción (3): más ancho por ser el campo más largo; con ellipsis a 2 líneas.
///   - Ámbito (1.5):    badge compacto del ámbito; no necesita mucho espacio.
///
/// Colores de ámbito ([_ambitoColor]):
///   - SERV → azul   (`0xFF388BFD`): permisos sobre servidores.
///   - USER → verde  (`0xFF3FB950`): permisos sobre usuarios/grupos.
///   - SYS  → dorado (`0xFFE3B341`): permisos sobre el sistema.
///   - otro → gris   (`0xFF8B949E`): ámbito desconocido o nuevo.
class _PermisosTable extends StatelessWidget {
  /// Lista de IDs de permiso a resolver y mostrar.
  final List<int> permisoIds;

  /// Referencia al provider para resolver IDs de permiso a objetos [Permiso].
  /// Se recibe como parámetro en lugar de leerlo del contexto para evitar
  /// suscripciones innecesarias dentro de un widget de tabla estático.
  final GrupoProvider grupoProvider;

  const _PermisosTable({required this.permisoIds, required this.grupoProvider});

  @override
  Widget build(BuildContext context) {
    if (permisoIds.isEmpty) {
      return const Text(
        'Sin permisos',
        style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2), // Nombre
        1: FlexColumnWidth(3), // Descripción (campo más largo)
        2: FlexColumnWidth(1.5), // Ámbito (badge compacto)
      },
      children: [
        // Fila de cabecera con borde inferior como separador visual.
        const TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
          ),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Nombre',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Descripción',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Ámbito',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
              ),
            ),
          ],
        ),
        // Una fila por cada ID de permiso. Si el ID no se encuentra en el
        // catálogo, se usa el fallback #id / - / widget vacío.
        ...permisoIds.map((id) {
          final permiso = grupoProvider.getPermisoById(id);
          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF21262D))),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  // Fallback: muestra "#id" si el permiso no está en el catálogo.
                  permiso?.nombre ?? '#$id',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  permiso?.descripcion ?? '-',
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: permiso != null
                    ? StatusBadge(
                        label: permiso.ambito.nombre,
                        color: _ambitoColor(permiso.ambito.nombre),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Devuelve el color asociado a un nombre de ámbito de permiso.
  ///
  /// El mapeo es insensible a mayúsculas (se normaliza a uppercase antes de
  /// comparar). Los colores son consistentes con los usados en [_PermsSummary]
  /// de grupos_screen.dart: azul para SERV, verde para USER, dorado para SYS.
  ///
  /// Si el ámbito no coincide con ninguno de los conocidos (SERV, USER, SYS),
  /// devuelve gris neutro para no romper el diseño ante ámbitos futuros de api-py.
  Color _ambitoColor(String ambito) {
    switch (ambito.toUpperCase()) {
      case 'SERV':
        return const Color(0xFF388BFD); // Azul: permisos sobre servidores
      case 'USER':
        return const Color(0xFF3FB950); // Verde: permisos sobre usuarios/grupos
      case 'SYS':
        return const Color(0xFFE3B341); // Dorado: permisos sobre el sistema
      default:
        return const Color(0xFF8B949E); // Gris: ámbito desconocido
    }
  }
}
