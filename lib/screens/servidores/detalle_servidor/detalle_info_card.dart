/// detalle_info_card.dart
///
/// Propósito:
///   Tarjeta de información técnica de un servidor dentro de la pantalla de
///   detalle. Muestra los campos de identidad y sistema del servidor (Server ID,
///   hostname, DNS, SO, arquitectura, kernel y sección) como filas [InfoRow].
///
/// Capa arquitectónica:
///   Capa de presentación — componente de detalle de servidor
///   (screens/servidores/detalle_servidor/).
///   Es un widget de presentación pura: no accede a providers ni realiza
///   peticiones HTTP. Recibe [Servidor] y [Seccion] ya resueltos desde el padre.
///
/// Campos condicionales:
///   Varios campos de [Servidor] pueden ser `null` si api-py no los incluyó en
///   la respuesta (p. ej. servidor recién registrado sin agente). Solo se
///   renderizan las filas de los campos con valor:
///   - Siempre visibles: Server ID, Hostname, DNS.
///   - Opcionales: Sistema operativo, Arquitectura, Kernel, Sección.
///
/// Resolución de sección:
///   [Servidor.seccion] es un ID entero de clave foránea. El padre
///   (DetalleServidorScreen) resuelve ese ID a un objeto [Seccion] usando
///   `ServidorProvider.seccionesCache` y lo pasa aquí. Si el caché no está
///   cargado o el ID no existe en él, [seccion] llega como `null` y la fila
///   de sección no se muestra.
///
/// Qué NO debe contener este fichero:
///   - Acceso a providers ni lógica de resolución de IDs.
///   - Lógica de navegación.
///   - Campos de otros dominios (servicios, métricas) que pertenecen a otras tarjetas.
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_seccion.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';

/// Tarjeta de información técnica del sistema de un servidor.
///
/// Responsabilidad:
///   Presentar en formato de lista de filas los datos técnicos del [servidor]:
///   identidad (Server ID, hostname, DNS), sistema operativo, arquitectura,
///   kernel y sección de pertenencia. Los campos opcionales solo aparecen si
///   el objeto [Servidor] los tiene poblados.
///
/// Relación con otros módulos:
///   - [DetalleServidorScreen]: instancia esta tarjeta pasando el servidor y la
///     sección ya resuelta desde el caché del provider.
///   - [ServidorProvider.seccionesCache]: fuente de la resolución del ID de sección
///     al objeto [Seccion] completo (resolución que ocurre en el padre, no aquí).
///   - [SectionHeader]: cabecera "Información del sistema" con icono.
///   - [InfoRow]: cada campo se renderiza como una fila icono + etiqueta + valor.
///
/// Valor de la sección:
///   Si [seccion] no es `null`, el valor del [InfoRow] concatena el nombre de
///   la sección y, si existe, su descripción en una línea adicional
///   (`nombre\ndescripción`). El salto de línea permite mostrar más contexto
///   sin ocupar una fila separada.
class DetalleInfoCard extends StatelessWidget {
  /// Servidor del que se muestran los datos de sistema.
  final Servidor servidor;

  /// Sección resuelta del servidor. `null` si el caché no está cargado o si
  /// [Servidor.seccion] no coincide con ninguna entrada del caché.
  final Seccion? seccion;

  const DetalleInfoCard({
    super.key,
    required this.servidor,
    required this.seccion,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Información del sistema',
              icon: Icons.info_outline,
            ),
            // ── Campos siempre visibles ───────────────────────────────────
            InfoRow(
              icon: Icons.badge_outlined,
              label: 'Server ID',
              value: servidor.serverId,
            ),
            InfoRow(
              icon: Icons.computer,
              label: 'Hostname',
              value: servidor.hostname,
            ),
            InfoRow(icon: Icons.language, label: 'DNS', value: servidor.dns),
            // ── Campos opcionales (null si api-py no los incluyó) ─────────
            if (servidor.prettyOs != null)
              InfoRow(
                icon: Icons.terminal,
                label: 'Sistema operativo',
                value: servidor.prettyOs!,
              ),
            if (servidor.arch != null)
              InfoRow(
                icon: Icons.memory,
                label: 'Arquitectura',
                value: servidor.arch!,
              ),
            if (servidor.kernel != null)
              InfoRow(
                icon: Icons.layers_outlined,
                label: 'Kernel',
                value: servidor.kernel!,
              ),
            // La sección es null si el caché del provider no está cargado o si
            // el ID de Servidor.seccion no existe en ServidorProvider.seccionesCache.
            if (seccion != null)
              InfoRow(
                icon: Icons.folder_outlined,
                label: 'Sección',
                // Nombre de la sección + descripción en segunda línea (si existe).
                value:
                    seccion!.nombre +
                    (seccion!.descripcion != null
                        ? '\n${seccion!.descripcion}'
                        : ''),
              ),
          ],
        ),
      ),
    );
  }
}
