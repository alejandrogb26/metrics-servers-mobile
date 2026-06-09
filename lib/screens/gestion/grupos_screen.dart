/// grupos_screen.dart
///
/// Propósito:
///   Pantalla de administración de grupos de usuarios de Metrics Manager.
///   Muestra la lista de grupos registrados en api-py, con su nombre, DN,
///   badge de superadmin y resumen visual de permisos asignados. Permite
///   navegar al detalle de cada grupo para ver y editar sus permisos.
///
/// Capa arquitectónica:
///   Capa de presentación — pantallas de gestión (screens/gestion/).
///
/// Clases definidas en este fichero:
///   - [GruposScreen]:   StatefulWidget raíz de la pantalla; gestiona la carga.
///   - [_GrupoCard]:     Tarjeta visual de un grupo individual (privada).
///   - [_PermsSummary]:  Resumen de conteo de permisos globales y por sección (privado).
///   - [_MiniChip]:      Chip compacto de color para los contadores de permisos (privado).
///
/// Patrón de carga — FutureBuilder + Consumer:
///   La pantalla usa una combinación de dos mecanismos complementarios:
///
///   1. [FutureBuilder] sobre [_future] (almacenado en el estado): muestra el
///      spinner de carga mientras el Future no ha completado. Al almacenar el
///      Future en el estado (en lugar de pasarlo directamente), se evita que
///      cada rebuild de la pantalla relance la petición HTTP.
///
///   2. [Consumer<GrupoProvider>]: una vez el Future completa, el Consumer
///      toma el control y reacciona a cambios posteriores del provider (errores,
///      actualizaciones tras reintento). El provider es el que notifica si hay
///      nuevos datos o errores.
///
/// Acceso y permisos:
///   Esta pantalla está destinada a usuarios con permiso AUDIT_USER o superAdmin.
///   No verifica los permisos internamente; se asume que la navegación hacia
///   ella solo ocurre si el usuario tiene acceso (controlado en [HomeScreen]).
///
/// Qué NO debe contener este fichero:
///   - Lógica HTTP directa (pertenece a GrupoService).
///   - Lógica de edición de grupos (pertenece a DetalleGrupoScreen).
///   - Widgets reutilizables fuera de esta pantalla (pertenecen a shared_widgets).
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_grupo.dart';
import 'package:metrics_servers_mobile/providers/grupo_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';
import 'package:provider/provider.dart';

/// Pantalla de listado de grupos de usuarios.
///
/// Responsabilidad:
///   Orquesta la carga de grupos mediante [GrupoProvider.fetchAll] y muestra
///   la lista resultante. Gestiona los estados de carga, error y vacío con
///   los widgets compartidos de la app.
///
/// Ciclo de vida:
///   - [initState]: lee el provider sin escucharlo (`context.read`) y lanza
///     [GrupoProvider.fetchAll], almacenando el Future en [_future]. Si el
///     provider ya tenía datos cargados, el Future resuelve inmediatamente y
///     no se hace ninguna petición HTTP.
///   - [build]: delega la representación del estado de carga al [FutureBuilder]
///     y la del estado de datos al [Consumer].
///   - [_retry]: invalida el caché del provider y lanza una nueva carga,
///     actualizando [_future] mediante [setState] para re-disparar el FutureBuilder.
///
/// Relación con otros módulos:
///   - [GrupoProvider]: fuente de datos; [fetchAll] carga grupos y permisos.
///   - [AppRoutes.detalleGrupo]: destino de navegación al pulsar un grupo,
///     recibiendo el objeto [Grupo] completo como argumento.
class GruposScreen extends StatefulWidget {
  const GruposScreen({super.key});

  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  /// Future de la carga activa. Se almacena en el estado para que los rebuilds
  /// del widget no relancen la petición HTTP. Solo se reemplaza en [_retry].
  late Future<void> _future;

  /// Referencia directa al provider, obtenida en [initState] con `context.read`
  /// para evitar escuchas innecesarias desde el estado.
  late GrupoProvider _provider;

  @override
  void initState() {
    super.initState();
    // context.read<T>() es equivalente a Provider.of<T>(context, listen: false):
    // obtiene la instancia del provider sin suscribirse a sus cambios.
    // Es adecuado en initState porque no crea una dependencia reactiva con el contexto.
    _provider = context.read<GrupoProvider>();
    _future = _provider.fetchAll();
  }

  /// Invalida el caché del provider y relanza la carga desde cero.
  ///
  /// Llama a [GrupoProvider.invalidate] para limpiar datos y flags, luego
  /// usa [setState] para reemplazar [_future] con un nuevo Future. Sin el
  /// [setState], el FutureBuilder no detectaría el cambio de Future y no
  /// volvería al estado de carga.
  void _retry() {
    _provider.invalidate();
    setState(() {
      _future = _provider.fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de grupos')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          // Mientras el Future no completa, mostrar spinner de carga.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingWidget(message: 'Cargando grupos…');
          }
          // Una vez completado el Future, el Consumer gestiona los cambios
          // posteriores del provider (reintento, actualización de datos).
          return Consumer<GrupoProvider>(
            builder: (context, provider, _) {
              if (provider.error != null) {
                return AppErrorWidget(
                  message: provider.error!,
                  onRetry: _retry,
                );
              }
              final grupos = provider.grupos;
              if (grupos.isEmpty) {
                return const EmptyStateWidget(
                  message: 'No hay grupos registrados',
                  icon: Icons.group_outlined,
                );
              }
              // RefreshIndicator habilita pull-to-refresh sobre la lista.
              return RefreshIndicator(
                onRefresh: () async => _retry(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: grupos.length,
                  itemBuilder: (_, i) => _GrupoCard(grupo: grupos[i]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Tarjeta visual de un grupo individual en la lista de gestión.
///
/// Responsabilidad:
///   Renderiza la información de un [Grupo] de forma compacta: icono con color
///   diferenciado por nivel de privilegio, nombre, DN y resumen de permisos.
///   Al pulsar, navega a [AppRoutes.detalleGrupo] pasando el [Grupo] como
///   argumento de navegación.
///
/// Diferenciación visual superAdmin vs. grupo normal:
///   - Superadmin: icono dorado ([Icons.admin_panel_settings]) + badge "SUPERADMIN".
///   - Normal:     icono azul ([Icons.group_outlined]), sin badge.
///   Esta distinción visual permite al administrador identificar rápidamente los
///   grupos con privilegios elevados en la lista.
///
/// Permisos:
///   El resumen de permisos ([_PermsSummary]) solo se muestra si [Grupo.permisos]
///   no es `null`. Un grupo sin datos de permisos (p. ej. cargado sin detalle)
///   no mostrará la sección de permisos.
class _GrupoCard extends StatelessWidget {
  final Grupo grupo;
  const _GrupoCard({required this.grupo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.detalleGrupo,
          arguments: grupo,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono con color de fondo diferenciado según privilegio del grupo.
              // Superadmin usa dorado; grupos normales usan azul primario.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: grupo.superAdmin
                      ? const Color(0xFFE3B341).withValues(alpha: 0.12)
                      : const Color(0xFF1F6FEB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  grupo.superAdmin
                      ? Icons.admin_panel_settings
                      : Icons.group_outlined,
                  color: grupo.superAdmin
                      ? const Color(0xFFE3B341)
                      : const Color(0xFF1F6FEB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            grupo.nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        // Badge "SUPERADMIN" solo visible para grupos con superAdmin.
                        if (grupo.superAdmin)
                          const StatusBadge(
                            label: 'SUPERADMIN',
                            color: Color(0xFFE3B341),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // DN con ellipsis: puede ser un string LDAP largo.
                    Text(
                      grupo.dn,
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Resumen de permisos solo si están disponibles en el modelo.
                    if (grupo.permisos != null) ...[
                      const SizedBox(height: 6),
                      _PermsSummary(permisos: grupo.permisos!),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8B949E)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resumen visual del conteo de permisos de un grupo.
///
/// Responsabilidad:
///   Muestra dos chips opcionales con el número de permisos globales y el número
///   total de permisos por sección del grupo. Permite al administrador ver de un
///   vistazo el nivel de permisos asignado sin entrar al detalle.
///
/// Conteo de permisos:
///   - [totalGlobal]: número de IDs en [GrupoPermissionMap.global].
///   - [totalSections]: suma de todos los IDs en todas las listas de
///     [GrupoPermissionMap.sections] (total de permisos de sección, no número
///     de secciones).
///
/// Cada chip solo se renderiza si su contador es mayor que cero: un grupo
/// sin permisos globales no muestra el chip azul; un grupo sin permisos de
/// sección no muestra el chip verde.
///
/// Usa [Wrap] para manejar el overflow: si ambos chips no caben en una línea,
/// el segundo fluye a la siguiente de forma automática.
class _PermsSummary extends StatelessWidget {
  final GrupoPermissionMap permisos;
  const _PermsSummary({required this.permisos});

  @override
  Widget build(BuildContext context) {
    final totalGlobal = permisos.global.length;
    // Calcula el número total de permisos definidos dentro de las secciones.
    //
    // `permisos.sections` es un mapa donde cada entrada representa una sección
    // de la aplicación y su valor asociado es una lista con los permisos de esa
    // sección.
    //
    // Con `.values` se obtienen únicamente las listas de permisos del mapa,
    // ignorando las claves o nombres de las secciones.
    //
    // Después, `fold<int>` recorre cada una de esas listas y va acumulando su
    // tamaño. El acumulador comienza en 0 y, por cada lista encontrada, se suma
    // `list.length`, es decir, la cantidad de permisos que contiene esa sección.
    //
    // El resultado final será la suma de todos los permisos existentes en todas
    // las secciones.
    final totalSections = permisos.sections.values.fold<int>(
      0,
      (acc, list) => acc + list.length,
    );

    return Wrap(
      spacing: 6,
      children: [
        if (totalGlobal > 0)
          _MiniChip(
            // Pluralización manual: "1 global" / "N globales".
            label: '$totalGlobal global${totalGlobal != 1 ? "es" : ""}',
            color: const Color(0xFF388BFD),
          ),
        if (totalSections > 0)
          _MiniChip(
            label: '$totalSections por sección',
            color: const Color(0xFF3FB950),
          ),
      ],
    );
  }
}

/// Chip compacto de color para mostrar contadores de permisos.
///
/// Responsabilidad:
///   Renderiza una etiqueta pequeña con fondo y borde semitransparentes del
///   color indicado. Más compacto que [StatusBadge] (font size 10, padding
///   reducido, border radius cuadrado) para adaptarse al contexto de resumen
///   dentro de una tarjeta de lista.
///
/// Solo se usa dentro de [_PermsSummary]; no está destinado a reutilización
/// fuera de este fichero.
class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}
